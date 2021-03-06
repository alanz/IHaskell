{-# LANGUAGE DeriveFunctor #-}
module Language.Haskell.GHC.Parser (
  -- Parser handling
  runParser,
  LineNumber,
  ColumnNumber,
  ErrMsg,
  StringLoc(..),
  ParseOutput(..),
  Parser,
  Located(..),

  -- Different parsers
  parserStatement,
  parserImport,
  parserDeclaration,
  parserTypeSignature,
  parserModule,
  parserExpression,
  partialStatement,
  partialImport,
  partialDeclaration,
  partialTypeSignature,
  partialModule,
  partialExpression,

  -- Haskell string preprocessing.
  removeComments,
  layoutChunks,
  ) where

import Data.List (intercalate, findIndex)

import Bag
import ErrUtils hiding (ErrMsg)
import FastString
import GHC hiding (Located)
import Lexer
import OrdList
import Outputable hiding ((<>))
import SrcLoc hiding (Located)
import StringBuffer

import qualified Language.Haskell.GHC.HappyParser as Parse

-- | A line number in an input string.
type LineNumber   = Int

-- | A column number in an input string.
type ColumnNumber = Int

-- | An error message string.
type ErrMsg = String

-- | A location in an input string.
data StringLoc = Loc LineNumber ColumnNumber deriving (Show, Eq)

-- | Output from running a parser.
data ParseOutput a
    = Failure ErrMsg StringLoc    -- ^ Parser failed with given error message and location.
    | Parsed a                    -- ^ Parser succeeded with an output.
    | Partial a (String, String)  -- ^ Partial parser succeeded with an output.
    deriving (Eq, Show)                  -- Auxiliary strings say what part of the
                                  -- input string was used and what
                                  -- part is remaining.
                                  --
-- | Store locations along with a value.
data Located a = Located {
    line :: LineNumber, -- Where this element is located.
    unloc :: a          -- Located element. 
  } deriving (Eq, Show, Functor)


data ParserType = FullParser | PartialParser
data Parser a = Parser ParserType (P a)

-- Our parsers.
parserStatement      = Parser FullParser    Parse.fullStatement
parserImport         = Parser FullParser    Parse.fullImport
parserDeclaration    = Parser FullParser    Parse.fullDeclaration
parserExpression     = Parser FullParser    Parse.fullExpression
parserTypeSignature  = Parser FullParser    Parse.fullTypeSignature
parserModule         = Parser FullParser    Parse.fullModule
partialStatement     = Parser PartialParser Parse.partialStatement
partialImport        = Parser PartialParser Parse.partialImport
partialDeclaration   = Parser PartialParser Parse.partialDeclaration
partialExpression    = Parser PartialParser Parse.partialExpression
partialTypeSignature = Parser PartialParser Parse.partialTypeSignature
partialModule        = Parser PartialParser Parse.partialModule

-- | Run a GHC parser on a string. Return success or failure with
-- associated information for both.
runParser :: DynFlags -> Parser a -> String -> ParseOutput a
runParser flags (Parser parserType parser) str =
  -- Create an initial parser state.
  let filename = "<interactive>"
      location = mkRealSrcLoc (mkFastString filename) 1 1
      buffer = stringToStringBuffer str
      parseState = mkPState flags buffer location in
    -- Convert a GHC parser output into our own.
    toParseOut $ unP parser parseState
  where
    toParseOut :: ParseResult a -> ParseOutput a
    toParseOut (PFailed span@(RealSrcSpan realSpan) err) = 
      let errMsg = printErrorBag $ unitBag $ mkPlainErrMsg flags span err
          line = srcLocLine $ realSrcSpanStart realSpan
          col = srcLocCol $ realSrcSpanStart realSpan
        in Failure errMsg $ Loc line col

    toParseOut (PFailed span err) = 
      let errMsg = printErrorBag $ unitBag $ mkPlainErrMsg flags span err
        in Failure errMsg $ Loc 0 0

    toParseOut (POk parseState result) = 
      let parseEnd = realSrcSpanStart $ last_loc parseState
          endLine = srcLocLine parseEnd
          endCol = srcLocCol parseEnd
          (before, after) = splitAtLoc endLine endCol str in
        case parserType of
          PartialParser -> Partial result (before, after)
          FullParser -> Parsed result

    -- Convert the bag of errors into an error string.
    printErrorBag bag = joinLines . map show $ bagToList bag

-- | Split a string at a given line and column. The column is included in
-- the second part of the split.
splitAtLoc :: LineNumber -> ColumnNumber -> String -> (String, String)
splitAtLoc line col string = 
  if line > length (lines string)
  then (string, "")
  else (before, after)
  where
    (beforeLines, afterLines) = splitAt line $ lines string
    theLine = last beforeLines
    (beforeChars, afterChars) = splitAt (col - 1) theLine

    before = joinLines (init beforeLines) ++ '\n' : beforeChars
    after = joinLines $ afterChars : afterLines

-- Not the same as 'unlines', due to trailing \n
joinLines :: [String] -> String
joinLines = intercalate "\n"

-- | Split an input string into chunks based on indentation.
-- A chunk is a line and all lines immediately following that are indented
-- beyond the indentation of the first line. This parses Haskell layout
-- rules properly, and allows using multiline expressions via indentation. 
layoutChunks :: String -> [Located String]
layoutChunks = go 1
  where
    go :: LineNumber -> String -> [Located String]
    go line = filter (not . null . unloc) . map (fmap strip) . layoutLines line . lines

    -- drop spaces on left and right
    strip = dropRight . dropLeft
      where
        dropLeft = dropWhile (`elem` whitespace)
        dropRight = reverse . dropWhile (`elem` whitespace) . reverse
        whitespace = " \t\n"

    layoutLines :: LineNumber -> [String] -> [Located String]
    -- Empty string case.  If there's no input, output is empty.
    layoutLines _ [] = []

    -- Use the indent of the first line to find the end of the first block.
    layoutLines lineIdx all@(firstLine:rest) = 
      let firstIndent = indentLevel firstLine
          blockEnded line = indentLevel line <= firstIndent in
        case findIndex blockEnded rest of
          -- If the first block doesn't end, return the whole string, since
          -- that just means the block takes up the entire string. 
          Nothing -> [Located lineIdx $ intercalate "\n" all]

          -- We found the end of the block. Split this bit out and recurse.
          Just idx -> 
            let (before, after) = splitAt idx rest in
              Located lineIdx (joinLines $ firstLine:before) : go (lineIdx + idx + 1) (joinLines after)

    -- Compute indent level of a string as number of leading spaces.
    indentLevel :: String -> Int
    indentLevel (' ':str) = 1 + indentLevel str

    -- Count a tab as two spaces.
    indentLevel ('\t':str) = 2 + indentLevel str
  
    -- Count empty lines as a large indent level, so they're always with the previous expression.
    indentLevel "" = 100000

    indentLevel _ = 0

-- | Drop comments from Haskell source.
-- Simply gets rid of them, does not replace them in any way.
removeComments :: String -> String
removeComments = removeOneLineComments . removeMultilineComments 0
  where
    removeOneLineComments str =
      case str of
        -- Don't remove comments after cmd directives
        ':':'!':remaining ->":!" ++ takeLine remaining ++ dropLine remaining

        -- Handle strings.
        '"':remaining -> 
          let quoted = takeString remaining
              len = length quoted in
            '"':quoted ++ removeOneLineComments (drop len remaining)

        '-':'-':remaining -> dropLine remaining
        x:xs -> x:removeOneLineComments xs
        [] -> []
      where
        dropLine = removeOneLineComments . dropWhile (/= '\n')

    removeMultilineComments nesting str =
      case str of
        -- Don't remove comments after cmd directives
        ':':'!':remaining ->":!" ++ takeLine remaining ++
          removeMultilineComments nesting (dropWhile (/= '\n') remaining)

        -- Handle strings.
        '"':remaining -> 
          if nesting == 0
          then 
            let quoted = takeString remaining
                len = length quoted in
              '"':quoted ++ removeMultilineComments nesting (drop len remaining)
          else
            removeMultilineComments nesting remaining

        '{':'-':remaining -> removeMultilineComments (nesting + 1) remaining
        '-':'}':remaining -> 
          if nesting > 0
          then removeMultilineComments (nesting - 1) remaining
          else '-':'}':removeMultilineComments nesting remaining
        x:xs -> 
          if nesting > 0
          then removeMultilineComments nesting xs
          else x:removeMultilineComments nesting xs
        [] -> []

    takeLine = takeWhile (/= '\n')

    -- Take a part of a string that ends in an unescaped quote.
    takeString str = case str of
      escaped@('\\':'"':rest) -> escaped
      '"':rest -> "\""
      x:xs -> x:takeString xs
      [] -> []
