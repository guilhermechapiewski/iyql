{-# LANGUAGE CPP #-}
-- Copyright (c) 2010, Diego Souza
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 
--   * Redistributions of source code must retain the above copyright notice,
--     this list of conditions and the following disclaimer.
--   * Redistributions in binary form must reproduce the above copyright notice,
--     this list of conditions and the following disclaimer in the documentation
--     and/or other materials provided with the distribution.
--   * Neither the name of the <ORGANIZATION> nor the names of its contributors
--     may be used to endorse or promote products derived from this software
--     without specific prior written permission.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Test.Yql.Core.Parser where

#define eq assertEqual (__FILE__ ++":"++ show __LINE__)

import Yql.Core.Lexer
import Yql.Core.Parser
import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit (assertBool,assertEqual)
import Data.List
import Text.ParserCombinators.Parsec

suite :: [Test]
suite = [ testGroup "Parser.hs" [ test0
                                , test1
                                , test2
                                , test3
                                , test4
                                , test5
                                , test6
                                , test7
                                , test8
                                , test9
                                , test10
                                , test11
                                , test12
                                ]
        ]

test0 = testCase "select * without where" $ 
        eq "SELECT * FROM iyql;" (runYqlParser_ "select * from iyql;")

test1 = testCase "select foo,bar without where" $
        eq "SELECT foo,bar FROM iyql;" (runYqlParser_ "select foo,bar from iyql;")

test2 = testCase "select * with single where clause [text]" $
        eq "SELECT * FROM iyql WHERE foo=\"bar\";" (runYqlParser_ "select * from iyql where foo='bar';")

test3 = testCase "select * with single where clause [num]" $
        eq "SELECT * FROM iyql WHERE pi=3.141592653589793;" (runYqlParser_ "select * from iyql where pi=3.141592653589793;")

test4 = testCase "select * with multiple and/or" $
        eq "SELECT * FROM iyql WHERE foo=\"bar\" AND bar=\"foo\" OR id=me;" (runYqlParser_ "select * from iyql where foo=\"bar\" and bar=\"foo\" or id=me;")

test5 = testCase "select * with `in' clause" $ 
        eq "SELECT * FROM iyql WHERE foo IN (\"b\",\"a\",\"r\",3,\".\",1);" (runYqlParser_ "select * from iyql where foo in (\"b\",\"a\",\"r\",3,\".\",1);")

test6 = testCase "select * with functions" $
        do eq "SELECT * FROM iyql | iyql(field=\"foobar\");" (runYqlParser_ "select * from iyql | iyql(field='foobar');")
           eq "SELECT * FROM iyql | iyql() | sort();" (runYqlParser_ "select * from iyql | iyql() | sort();")

test7 = testCase "select * using local filters [like]" $
        do eq "SELECT * FROM iyql WHERE foo LIKE \"baz\";" (runYqlParser_ "select * from iyql where foo like \"baz\";")
           eq "SELECT * FROM iyql WHERE foo NOT LIKE \"baz\";" (runYqlParser_ "select * from iyql where foo not like \"baz\";")

test8 = testCase "select * using local filters [matches]" $  
        do eq "SELECT * FROM iyql WHERE foo MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo matches \".*.bar*\";")
           eq "SELECT * FROM iyql WHERE foo NOT MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo not matches \"bar\";")

test9 = testCase "select * using local filters [>,>=,=,!=,<,<=]" $
        do eq "SELECT * FROM iyql WHERE foo > 7;" (runYqlParser_ "select * from iyql where foo > 7;")
           eq "SELECT * FROM iyql WHERE foo >= 7;" (runYqlParser_ "select * from iyql where foo >= 7;")
           eq "SELECT * FROM iyql WHERE foo <= 7;" (runYqlParser_ "select * from iyql where foo <= 7;")
           eq "SELECT * FROM iyql WHERE foo < 7;" (runYqlParser_ "select * from iyql where foo < 7;")
           eq "SELECT * FROM iyql WHERE foo = 7;" (runYqlParser_ "select * from iyql where foo = 7;")
           eq "SELECT * FROM iyql WHERE foo != 7;" (runYqlParser_ "select * from iyql where foo != 7;")

test10 = testCase "select with where clause with different precedence" $
         do eq "SELECT * FROM iyql WHERE (foo=2 and bar=3) or (foo=5 and bar=7);" (runYqlParser_ "select * from iyql where (foo=2 and bar=3) or (foo=5 and bar=7);")
            eq "SELECT * FROM iyql WHERE (foo=2 or bar=3) and (foo=4 or bar=7);" (runYqlParser_ "select * from iyql where (foo=2 or bar=3) and (foo=5 or bar=7);")

test11 = testCase "local functions should not precede any remote functions" $ 
         do eq "parse error" (runYqlParser "select * from iyql | .bar() | foo();")

test12 = testCase "local and remote functions in the same query" $ 
         do eq "SELECT * FROM iyql | foo() | .bar();" (runYqlParser_ "select * from iyql | foo() | .bar();")

newtype LexerToken = LexerToken (String,TokenT)
                   deriving (Show)

showFunction [] = "";
showFunction f  = " | " ++ intercalate " | " f;

stringBuilder = ParserEvents { onIdentifier = id
                             , onTxtValue   = mkValue
                             , onNumValue   = id
                             , onMeValue    = "me"
                             , onSelect     = mkSelect
                             , onUpdate     = undefined
                             , onInsert     = undefined
                             , onDelete     = undefined
                             , onDesc       = undefined
                             , onEqExpr     = mkEqExpr
                             , onInExpr     = mkInExpr
                             , onAndExpr    = mkAndExpr
                             , onOrExpr     = mkOrExpr
                             , onLocalFunc  = mkFunc "."
                             , onRemoteFunc = mkFunc ""
                             }
  where mkValue v = "\"" ++ v ++ "\""
        
        mkSelect c t Nothing  f = "SELECT " ++ (intercalate "," c) ++ " FROM " ++ t ++ showFunction f ++ ";"
        mkSelect c t (Just w) f = "SELECT " ++ (intercalate "," c) ++ " FROM " ++ t ++ " WHERE " ++ w ++ showFunction f ++ ";"
        
        mkFunc p n as = p ++ n ++ "("++ intercalate "," (map showArg as) ++")"
          where showArg (k,v) = k ++"="++ v

        mkEqExpr c v = c ++"="++ v

        mkInExpr c vs = c ++ " IN ("++ intercalate "," vs ++")"

        mkAndExpr l r = l ++" AND "++ r

        mkOrExpr l r = l ++" OR "++ r

runYqlParser :: String -> String
runYqlParser input = case (parseYql input stringBuilder)
                     of Right output -> output
                        Left err     -> "parse error: " ++ (show err)

runYqlParser_ :: String -> String
runYqlParser_ input = case (parseYql input stringBuilder)
                          of Right output -> output
                             Left err     -> error "parse error"