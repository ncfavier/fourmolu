let data = ./data.dhall

let Prelude = ./Prelude.dhall

let indent =
      \(n : Natural) -> Text/replace "\n" ("\n" ++ Prelude.Text.replicate n " ")

let typeValueCommaList =
      \(fieldType : data.EnumType) ->
        let length = Prelude.List.length data.Enum fieldType.constructors

        let comma =
              \(i : Natural) ->
                    Prelude.Natural.greaterThan length 2
                &&  Prelude.Natural.lessThan (i + 1) length

        let space = \(i : Natural) -> Prelude.Natural.lessThan (i + 1) length

        let or = \(i : Natural) -> Prelude.Natural.equal (i + 2) length

        let when = \(b : Bool) -> \(t : Text) -> if b then t else ""

        in  Prelude.Text.concatMap
              { index : Natural, value : data.Enum }
              ( \(enum : { index : Natural, value : data.Enum }) ->
                      "\\\""
                  ++  data.showEnumPretty enum.value
                  ++  "\\\""
                  ++  when (comma enum.index) ","
                  ++  when (space enum.index) " "
                  ++  when (or enum.index) "or "
              )
              (Prelude.List.indexed data.Enum fieldType.constructors)

let list =
      \(n : Natural) ->
      \(T : Type) ->
      \(start : Text) ->
      \(separator : Text) ->
      \(f : T -> Text) ->
      \(xs : List T) ->
        indent
          n
          ( Prelude.Text.concatMapSep
              "\n"
              { index : Natural, value : T }
              ( \(x : { index : Natural, value : T }) ->
                  let lead =
                        if    Prelude.Natural.isZero x.index
                        then  start
                        else  separator

                  in  "${lead} ${f x.value}"
              )
              (Prelude.List.indexed T xs)
          )

let instancePrinterOptsFieldType =
      \(fieldType : data.FieldType) ->
        let def =
              merge
                { Enum =
                    \(x : data.EnumType) ->
                      ''
                      \s ->
                        case s of
                          ${indent 4 (Prelude.Text.concatMapSep
                              "\n"
                              data.Enum
                              (\(x : data.Enum) -> "\"${data.showEnumPretty x}\" -> Right ${data.showEnum x}")
                              x.constructors)}
                          _ ->
                            Left . unlines $
                              [ "unknown value: " <> show s
                              , "Valid values are: ${typeValueCommaList x}"
                              ]''
                , ADT = \(x : data.ADT) -> x.parsePrinterOptType
                }
                fieldType

        in  ''
            instance PrinterOptsFieldType ${data.typeName fieldType} where
              parsePrinterOptType = ${indent 2 def}''

let instanceFromJSON =
      \(fieldType : data.FieldType) ->
        let def =
              merge
                { Enum =
                    \(x : data.EnumType) ->
                      ''
                      Aeson.withText "${data.typeName fieldType}" $ \s ->
                        either Aeson.parseFail pure $
                          parsePrinterOptType (Text.unpack s)''
                , ADT = \(x : data.ADT) -> x.parseJSON
                }
                fieldType

        in  ''
            instance Aeson.FromJSON ${data.typeName fieldType} where
              parseJSON =
                ${indent 4 def}''

in  ''
{- FOURMOLU_DISABLE -}
{- ***** DO NOT EDIT: This module is autogenerated ***** -}

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Ormolu.Config.Gen
  ( PrinterOpts (..)
  ${list
      2
      data.FieldType
      ","
      ","
      (\(fieldType : data.FieldType) -> "${data.typeName fieldType} (..)")
      data.fieldTypes}
  , emptyPrinterOpts
  , defaultPrinterOpts
  , fillMissingPrinterOpts
  , parsePrinterOptsCLI
  , parsePrinterOptsJSON
  , parsePrinterOptType
  )
where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Types as Aeson
import Data.Functor.Identity (Identity)
import qualified Data.Text as Text
import GHC.Generics (Generic)
import Text.Read (readEither)

-- | Options controlling formatting output.
data PrinterOpts f =
  PrinterOpts
    ${list
        4
        data.Option
        "{"
        ","
        ( \(option : data.Option) ->
            ''
            -- | ${option.description}
              ${option.fieldName} :: f ${data.showType option.type}''
        )
        data.options}
    }
  deriving (Generic)

emptyPrinterOpts :: PrinterOpts Maybe
emptyPrinterOpts =
  PrinterOpts
    ${list
        4
        data.Option
        "{"
        ","
        (\(option : data.Option) -> "${option.fieldName} = Nothing")
        data.options}
    }

defaultPrinterOpts :: PrinterOpts Identity
defaultPrinterOpts =
  PrinterOpts
    ${list
        4
        data.Option
        "{"
        ","
        (\(option : data.Option) -> "${option.fieldName} = pure ${data.showValue option.default}")
        data.options}
    }

-- | Fill the field values that are 'Nothing' in the first argument
-- with the values of the corresponding fields of the second argument.
fillMissingPrinterOpts ::
  forall f.
  Applicative f =>
  PrinterOpts Maybe ->
  PrinterOpts f ->
  PrinterOpts f
fillMissingPrinterOpts p1 p2 =
  PrinterOpts
    ${list
        4
        data.Option
        "{"
        ","
        ( \(option : data.Option) ->
            "${option.fieldName} = maybe (${option.fieldName} p2) pure (${option.fieldName} p1)"
        )
        data.options}
    }

parsePrinterOptsCLI ::
  Applicative f =>
  (forall a. PrinterOptsFieldType a => String -> String -> String -> f (Maybe a)) ->
  f (PrinterOpts Maybe)
parsePrinterOptsCLI f =
  PrinterOpts
    ${list
        4
        data.Option
        "<$>"
        "<*>"
        ( \(option : data.Option) ->
            let choices =
                  merge
                    { Bool = ""
                    , Natural = ""
                    , Text = ""
                    , Enum = \(x : data.EnumType) -> "(choices: ${typeValueCommaList x}) "
                    , ADT = \(x : data.ADT) -> ""
                    }
                    option.type

            let default =
                  "${option.description} ${choices}(default: ${data.showValuePretty option.default})"

            in  ''
                f
                  "${option.name}"
                  "${merge
                       { Enum = \(x : data.EnumType) -> default
                       , Bool = default
                       , Natural = default
                       , Text = default
                       , ADT = \(x : data.ADT) -> x.cli
                       }
                       option.type}"
                  "${data.showPlaceholder option.type}"''
        )
        data.options}

parsePrinterOptsJSON ::
  Applicative f =>
  (forall a. PrinterOptsFieldType a => String -> f (Maybe a)) ->
  f (PrinterOpts Maybe)
parsePrinterOptsJSON f =
  PrinterOpts
    ${list
        4
        data.Option
        "<$>"
        "<*>"
        (\(option : data.Option) -> "f \"${option.name}\"")
        data.options}

{---------- PrinterOpts field types ----------}

class Aeson.FromJSON a => PrinterOptsFieldType a where
  parsePrinterOptType :: String -> Either String a

instance PrinterOptsFieldType Int where
  parsePrinterOptType = readEither

${instancePrinterOptsFieldType (data.FieldType.Enum data.Boolean)}


${Prelude.Text.concatMapSep
    "\n\n"
    data.FieldType
    ( \(fieldType : data.FieldType) ->
        ''
        data ${data.typeName fieldType}
          ${list
              2
              Text
              "="
              "|"
              (\(t : Text) -> t)
              ( merge
                  { Enum =
                      \(x : data.EnumType) ->
                        Prelude.List.map
                          data.Enum
                          Text
                          data.showEnum
                          x.constructors
                  , ADT = \(x : data.ADT) -> x.constructors
                  }
                  fieldType
              )}
          ${merge
              { Enum = \(x : data.EnumType) -> "deriving (Eq, Show, Enum, Bounded)"
              , ADT = \(x : data.ADT) -> "deriving (Eq, Show)"
              }
              fieldType}''
    )
    data.fieldTypes}

${Prelude.Text.concatMapSep
    "\n"
    data.FieldType
    ( \(fieldType : data.FieldType) ->
        ''
        ${instanceFromJSON fieldType}

        ${instancePrinterOptsFieldType fieldType}
        ''
    )
    data.fieldTypes}''
