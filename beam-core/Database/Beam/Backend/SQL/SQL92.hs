{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE PolyKinds #-}

module Database.Beam.Backend.SQL.SQL92 where

import Control.Monad.Identity hiding (join)

import Database.Beam.Schema.Tables
import Database.Beam.Backend.Types
import Database.Beam.Backend.SQL.Types

import Data.Proxy
import Data.Text (Text)

import GHC.Generics

class ( BeamSqlBackend be
      , Sql92Schema (BackendColumnSchema be)) =>
      BeamSql92Backend be where

-- * Schemas

class Sql92Schema schema where
  int :: schema
  smallint :: schema
  tinyint :: schema
  bigint :: schema

  char :: Word -> schema
  varchar :: Maybe Word -> schema

  float :: schema
  double :: schema

  timestamp :: schema

-- * Finally tagless style

class HasSqlValueSyntax expr ty where
  sqlValueSyntax :: ty -> expr
class IsSqlExpressionSyntaxStringType expr ty

type Sql92SelectExpressionSyntax select = Sql92SelectTableExpressionSyntax (Sql92SelectSelectTableSyntax select)
type Sql92SelectProjectionSyntax select = Sql92SelectTableProjectionSyntax (Sql92SelectSelectTableSyntax select)
type Sql92SelectGroupingSyntax select = Sql92SelectTableGroupingSyntax (Sql92SelectSelectTableSyntax select)
type Sql92SelectFromSyntax select = Sql92SelectTableFromSyntax (Sql92SelectSelectTableSyntax select)

class IsSql92Syntax cmd where
  type Sql92SelectSyntax cmd :: *
  type Sql92InsertSyntax cmd :: *
  type Sql92UpdateSyntax cmd :: *
  type Sql92DeleteSyntax cmd :: *

  selectCmd :: Sql92SelectSyntax cmd -> cmd
  insertCmd :: Sql92InsertSyntax cmd -> cmd
  updateCmd :: Sql92UpdateSyntax cmd -> cmd
  deleteCmd :: Sql92DeleteSyntax cmd -> cmd

class ( IsSql92SelectTableSyntax (Sql92SelectSelectTableSyntax select)
      , IsSql92OrderingSyntax (Sql92SelectOrderingSyntax select) ) =>
    IsSql92SelectSyntax select where
    type Sql92SelectSelectTableSyntax select :: *
    type Sql92SelectOrderingSyntax select :: *

    selectStmt :: Sql92SelectSelectTableSyntax select
               -> [Sql92SelectOrderingSyntax select]
               -> Maybe Integer {-^ LIMIT -}
               -> Maybe Integer {-^ OFFSET -}
               -> select

class ( IsSql92ExpressionSyntax (Sql92SelectTableExpressionSyntax select)
      , IsSql92ProjectionSyntax (Sql92SelectTableProjectionSyntax select)
      , IsSql92FromSyntax (Sql92SelectTableFromSyntax select)
      , IsSql92GroupingSyntax (Sql92SelectTableGroupingSyntax select)

      , Sql92GroupingExpressionSyntax (Sql92SelectTableGroupingSyntax select) ~ Sql92SelectTableExpressionSyntax select
      , Sql92FromExpressionSyntax (Sql92SelectTableFromSyntax select) ~ Sql92SelectTableExpressionSyntax select
      , Sql92SelectSelectTableSyntax (Sql92SelectTableSelectSyntax select) ~ select ) =>
    IsSql92SelectTableSyntax select where
  type Sql92SelectTableSelectSyntax select :: *
  type Sql92SelectTableExpressionSyntax select :: *
  type Sql92SelectTableProjectionSyntax select :: *
  type Sql92SelectTableFromSyntax select :: *
  type Sql92SelectTableGroupingSyntax select :: *

  selectTableStmt :: Sql92SelectTableProjectionSyntax select
                  -> Maybe (Sql92SelectTableFromSyntax select)
                  -> Maybe (Sql92SelectTableExpressionSyntax select)   {-^ Where clause -}
                  -> Maybe (Sql92SelectTableGroupingSyntax select)
                  -> Maybe (Sql92SelectTableExpressionSyntax select) {-^ having clause -}
                  -> select

  unionTables, intersectTables, exceptTable ::
    Bool -> select -> select -> select

class IsSql92InsertSyntax insert where
  type Sql92InsertValuesSyntax insert :: *
  insertStmt :: Text
             -> [ Text ]
             -> Sql92InsertValuesSyntax insert
             -> insert

class IsSql92InsertValuesSyntax insertValues where
  type Sql92InsertValuesExpressionSyntax insertValues :: *
  type Sql92InsertValuesSelectSyntax insertValues :: *

  insertSqlExpressions :: [ [ Sql92InsertValuesExpressionSyntax insertValues ] ]
                       -> insertValues
  insertFromSql :: Sql92InsertValuesSelectSyntax insertValues
                -> insertValues

class IsSql92UpdateSyntax update where
  type Sql92UpdateFieldNameSyntax update :: *
  type Sql92UpdateExpressionSyntax update :: *

  updateStmt :: Text
             -> [(Sql92UpdateFieldNameSyntax update, Sql92UpdateExpressionSyntax update)]
             -> Sql92UpdateExpressionSyntax update {-^ WHERE -}
             -> update

class IsSql92DeleteSyntax delete where
  type Sql92DeleteExpressionSyntax delete :: *

  deleteStmt :: Text
             -> Sql92DeleteExpressionSyntax delete
             -> delete

class IsSql92FieldNameSyntax fn where
  qualifiedField :: Text -> Text -> fn
  unqualifiedField :: Text -> fn

class IsSql92QuantifierSyntax quantifier where
  quantifyOverAll, quantifyOverAny :: quantifier

class ( HasSqlValueSyntax (Sql92ExpressionValueSyntax expr) Int
      , IsSql92FieldNameSyntax (Sql92ExpressionFieldNameSyntax expr) ) =>
    IsSql92ExpressionSyntax expr where
  type Sql92ExpressionQuantifierSyntax expr :: *
  type Sql92ExpressionValueSyntax expr :: *
  type Sql92ExpressionSelectSyntax expr :: *
  type Sql92ExpressionFieldNameSyntax expr :: *
  type Sql92ExpressionCastTargetSyntax expr :: *
  type Sql92ExpressionExtractFieldSyntax expr :: *

  valueE :: Sql92ExpressionValueSyntax expr -> expr
  rowE, coalesceE :: [ expr ] -> expr
  caseE :: [(expr, expr)]
        -> expr -> expr
  fieldE :: Sql92ExpressionFieldNameSyntax expr -> expr

  betweenE :: expr -> expr -> expr -> expr

  andE, orE, addE, subE, mulE, divE, likeE,
    modE, overlapsE, nullIfE, positionE
    :: expr
    -> expr
    -> expr

  eqE, neqE, ltE, gtE, leE, geE
    :: Maybe (Sql92ExpressionQuantifierSyntax expr)
    -> expr -> expr -> expr

  castE :: expr -> Sql92ExpressionCastTargetSyntax expr -> expr

  notE, negateE, isNullE, isNotNullE,
    isTrueE, isNotTrueE, isFalseE, isNotFalseE,
    isUnknownE, isNotUnknownE, charLengthE,
    octetLengthE, bitLengthE
    :: expr
    -> expr

  -- | Included so that we can easily write a Num instance, but not defined in SQL92.
  --   Implementations that do not support this, should use CASE .. WHEN ..
  absE :: expr -> expr

  extractE :: Sql92ExpressionExtractFieldSyntax expr -> expr -> expr

  existsE, uniqueE, subqueryE
    :: Sql92ExpressionSelectSyntax expr -> expr

class IsSql92AggregationExpressionSyntax expr where
  type Sql92AggregationSetQuantifierSyntax expr :: *

  countAllE :: expr
  countE, avgE, maxE, minE, sumE
    :: Maybe (Sql92AggregationSetQuantifierSyntax expr) -> expr -> expr

class IsSql92AggregationSetQuantifierSyntax q where
  setQuantifierDistinct, setQuantifierAll :: q

class IsSql92ExpressionSyntax (Sql92ProjectionExpressionSyntax proj) => IsSql92ProjectionSyntax proj where
  type Sql92ProjectionExpressionSyntax proj :: *

  projExprs :: [ (Sql92ProjectionExpressionSyntax proj, Maybe Text) ]
            -> proj

class IsSql92OrderingSyntax ord where
  type Sql92OrderingExpressionSyntax ord :: *
  ascOrdering, descOrdering
    :: Sql92OrderingExpressionSyntax ord -> ord

class IsSql92TableSourceSyntax tblSource where
  type Sql92TableSourceSelectSyntax tblSource :: *
  tableNamed :: Text -> tblSource
  tableFromSubSelect :: Sql92TableSourceSelectSyntax tblSource -> tblSource

class IsSql92GroupingSyntax grouping where
  type Sql92GroupingExpressionSyntax grouping :: *

  groupByExpressions :: [ Sql92GroupingExpressionSyntax grouping ] -> grouping

class ( IsSql92TableSourceSyntax (Sql92FromTableSourceSyntax from)
      , IsSql92ExpressionSyntax (Sql92FromExpressionSyntax from) ) =>
    IsSql92FromSyntax from where
  type Sql92FromTableSourceSyntax from :: *
  type Sql92FromExpressionSyntax from :: *

  fromTable :: Sql92FromTableSourceSyntax from
            -> Maybe Text
            -> from

  innerJoin, leftJoin, rightJoin
    :: from -> from
      -> Maybe (Sql92FromExpressionSyntax from)
      -> from

-- class Sql92Syntax cmd where

--   -- data Sql92ValueSyntax cmd :: *
--   -- data Sql92FieldNameSyntax cmd :: *

--   selectCmd :: Sql92SelectSyntax cmd -> cmd


--   -- data Sql92TableSourceSyntax cmd :: *

--   -- data Sql92InsertValuesSyntax cmd ::  *

--   -- data Sql92AliasingSyntax cmd :: * -> *

--   insertSqlExpressions :: [ [ Sql92ExpressionSyntax cmd ] ]
--                        -> Sql92InsertValuesSyntax cmd
--   insertFromSql :: Sql92SelectSyntax cmd
--                 -> Sql92InsertValuesSyntax cmd

--   -- nullV     :: Sql92ValueSyntax cmd
--   -- trueV     :: Sql92ValueSyntax cmd
--   -- falseV    :: Sql92ValueSyntax cmd
--   -- stringV   :: String -> Sql92ValueSyntax cmd
--   -- numericV  :: Integer -> Sql92ValueSyntax cmd
--   -- rationalV :: Rational -> Sql92ValueSyntax cmd

--   -- aliasExpr :: Sql92ExpressionSyntax cmd
--   --           -> Maybe Text
--   --           -> Sql92AliasingSyntax cmd (Sql92ExpressionSyntax cmd)

--   -- projExprs :: [Sql92AliasingSyntax cmd (Sql92ExpressionSyntax cmd)]
--   --           -> Sql92ProjectionSyntax cmd

--   -- ascOrdering, descOrdering
--   --   :: Sql92ExpressionSyntax cmd -> Sql92OrderingSyntax cmd

--   tableNamed :: Text -> Sql92TableSourceSyntax cmd

--   -- fromTable
--   --   :: Sql92TableSourceSyntax cmd
--   --   -> Maybe Text
--   --   -> Sql92FromSyntax cmd

--   innerJoin, leftJoin, rightJoin
--     :: Sql92FromSyntax cmd
--     -> Sql92FromSyntax cmd
--     -> Maybe (Sql92ExpressionSyntax cmd)
--     -> Sql92FromSyntax cmd

-- instance HasSqlValueSyntax Sql92SyntaxBuilder Int32 where
--   sqlValueSyntax = numericV . fromIntegral

-- -- | Build a query using ANSI SQL92 syntax. This is likely to work out-of-the-box
-- --   in many databases, but its use is a security risk, as different databases have
-- --   different means of escaping values. It is best to customize this class per-backend
-- instance Sql92Syntax Sql92SyntaxBuilder where

--   trueV = Sql92ValueSyntaxBuilder (Sql92SyntaxBuilder (byteString "TRUE"))
--   falseV = Sql92ValueSyntaxBuilder (Sql92SyntaxBuilder (byteString "FALSE"))
--   stringV x = Sql92ValueSyntaxBuilder . Sql92SyntaxBuilder $
--                 byteString "\'" <>
--                 stringUtf8 (foldMap escapeChar x) <>
--                 byteString "\'"
--     where escapeChar '\'' = "''"
--           escapeChar x = [x]
--   numericV x = Sql92ValueSyntaxBuilder (Sql92SyntaxBuilder (stringUtf8 (show x)))
--   rationalV x = let Sql92ExpressionSyntaxBuilder e =
--                         divE (valueE (numericV (numerator x)))
--                              (valueE (numericV (denominator x)))
--                 in Sql92ValueSyntaxBuilder e
--   nullV = Sql92ValueSyntaxBuilder (Sql92SyntaxBuilder (byteString "NULL"))

--   fromTable tableSrc Nothing = coerce tableSrc
--   fromTable tableSrc (Just nm) =
--     Sql92FromSyntaxBuilder . Sql92SyntaxBuilder $
--     buildSql92 (coerce tableSrc) <> byteString " AS " <> stringUtf8 (T.unpack nm)

--   innerJoin = join "INNER JOIN"
--   leftJoin = join "LEFT JOIN"
--   rightJoin = join "RIGHT JOIN"

--   tableNamed nm = Sql92TableSourceSyntaxBuilder (Sql92SyntaxBuilder (stringUtf8 (T.unpack nm)))

-- * Make SQL Literals

type MakeSqlLiterals syntax t = FieldsFulfillConstraint (HasSqlValueSyntax syntax) t

makeSqlLiterals ::
  forall sql t.
  MakeSqlLiterals sql t =>
  t Identity -> t (WithConstraint (HasSqlValueSyntax sql))
makeSqlLiterals tbl =
  to (gWithConstrainedFields (Proxy @(HasSqlValueSyntax sql)) (Proxy @(Rep (t Exposed))) (from tbl))

insertValuesGeneric ::
    forall syntax table exprValues.
    ( Beamable table
    , IsSql92InsertValuesSyntax syntax
    , IsSql92ExpressionSyntax (Sql92InsertValuesExpressionSyntax syntax)
    , exprValues ~ Sql92ExpressionValueSyntax (Sql92InsertValuesExpressionSyntax syntax)
    , MakeSqlLiterals exprValues table ) =>
    [ table Identity ] -> syntax
insertValuesGeneric tbls =
    insertSqlExpressions (map mkSqlExprs tbls)
  where
    mkSqlExprs = allBeamValues
                   (\(Columnar' (WithConstraint x :: WithConstraint (HasSqlValueSyntax exprValues) x)) ->
                        valueE (sqlValueSyntax x)) .
                 makeSqlLiterals
