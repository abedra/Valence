module Main where
import System.Environment
import Control.Monad
import Text.ParserCombinators.Parsec hiding (spaces)

data LispVal = Atom String
     | List [LispVal]
     | DottedList [LispVal] LispVal
     | Number Integer
     | String String
     | Bool Bool

symbol :: Parser Char
symbol = oneOf "#!$%&|*+-/:<=>?@^_-"

primitives :: [(String, [LispVal] -> LispVal)]
primitives = [("+", operator (+)),
              ("-", operator (-)),
              ("*", operator (*)),
              ("/", operator div),
              ("mod", operator mod),
              ("quotient", operator quot),
              ("remainder", operator rem)]

operator :: (Integer -> Integer -> Integer) -> [LispVal] -> LispVal
operator op params = Number $ foldl1 op $ map unpackNum params

unpackNum :: LispVal -> Integer
unpackNum (Number n) = n
unpackNum (String n) = let parsed = reads n in
                           if null parsed
                              then 0
                              else fst $ parsed !! 0
unpackNum (List [n]) = unpackNum n
unpackNum _ = 0

spaces :: Parser ()
spaces = skipMany1 space

parseString :: Parser LispVal
parseString = do char '"'
                 x <- many (noneOf "\"")
                 char '"'
                 return $ String x

parseAtom :: Parser LispVal
parseAtom = do first <- letter <|> symbol
               rest <- many (letter <|> digit <|> symbol)
               let atom = first:rest
               return $ case atom of
                             "#t" -> Bool True
                             "#f" -> Bool False
                             _    -> Atom atom

parseNumber :: Parser LispVal
parseNumber = liftM (Number . read) $ many1 digit

parseList :: Parser LispVal
parseList = liftM List $ sepBy parseExpr spaces

parseDottedList :: Parser LispVal
parseDottedList = do
                head <- endBy parseExpr spaces
                tail <- char '.' >> spaces >> parseExpr
                return $ DottedList head tail

parseQuoted :: Parser LispVal
parseQuoted = do
            char '\''
            x <- parseExpr
            return $ List [Atom "quote", x]

parseExpr :: Parser LispVal
parseExpr = parseAtom
          <|> parseString
          <|> parseNumber
          <|> parseQuoted
          <|> do char '('
                 x <- try parseList <|> parseDottedList
                 char ')'
                 return x

instance Show LispVal where show = showVal
unwordsList :: [LispVal] -> String
unwordsList = unwords . map showVal

showVal :: LispVal -> String
showVal (String contents) = "\"" ++ contents ++ "\""
showVal (Atom name) = name
showVal (Number contents) = show contents
showVal (Bool True) = "#t"
showVal (Bool False) = "f"
showVal (List contents) = "(" ++ unwordsList contents ++ ")"
showVal (DottedList head tail) = "(" ++ unwordsList head ++ " . " ++ showVal tail ++ ")"

readExpr :: String -> LispVal
readExpr input = case parse parseExpr "lisp" input of
         Left err -> String $ "No match: " ++ show err
         Right val -> val

apply :: String -> [LispVal] -> LispVal
apply func args = maybe (Bool False) ($ args) $ lookup func primitives

eval :: LispVal -> LispVal
eval val@(String _) = val
eval val@(Number _) = val
eval val@(Bool _) = val
eval (List [Atom "quote", val]) = val
eval (List (Atom func : args)) = apply func $ map eval args

main :: IO ()
main = getArgs >>= print . eval . readExpr . head
