module Morphir.Graph.Tripler exposing
    ( NodeType(..)
    , Object(..)
    , Triple
    , Verb(..)
    , mapDistribution
    , nodeTypeToString
    , verbToString
    )

import Dict
import Morphir.IR.AccessControlled exposing (withPublicAccess)
import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.FQName as FQName exposing (FQName(..))
import Morphir.IR.Module as Module
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Package as Package exposing (PackageName)
import Morphir.IR.Path as Path
import Morphir.IR.Type as Type exposing (Constructor(..), Specification(..), Type(..))


type NodeType
    = Record
    | Field
    | Type
    | Function


type Object
    = Other String
    | FQN FQName
    | Node NodeType



-- | PathOf Path.Path


type Verb
    = IsA
    | Contains
    | Uses


type alias Triple =
    { subject : FQName
    , verb : Verb
    , object : Object
    }


mapDistribution : Distribution -> List Triple
mapDistribution distro =
    case distro of
        Distribution.Library packageName _ packageDef ->
            mapPackageDefinition packageName packageDef


mapPackageDefinition : Package.PackageName -> Package.Definition ta va -> List Triple
mapPackageDefinition packageName packageDef =
    packageDef.modules
        |> Dict.toList
        |> List.concatMap
            (\( moduleName, accessControlledModuleDef ) ->
                mapModuleDefinition packageName moduleName accessControlledModuleDef.value
            )


mapModuleDefinition : Package.PackageName -> Module.ModuleName -> Module.Definition ta va -> List Triple
mapModuleDefinition packageName moduleName moduleDef =
    moduleDef.types
        |> Dict.toList
        |> List.concatMap
            (\( typeName, accessControlledDocumentedTypeDef ) ->
                mapTypeDefinition packageName moduleName typeName accessControlledDocumentedTypeDef.value.value
            )


mapTypeDefinition : Package.PackageName -> Module.ModuleName -> Name -> Type.Definition ta -> List Triple
mapTypeDefinition packageName moduleName typeName typeDef =
    let
        fqn =
            FQName packageName moduleName typeName

        triples =
            case typeDef of
                Type.TypeAliasDefinition _ (Type.Record _ fields) ->
                    let
                        recordTriple =
                            Triple fqn IsA (Node Record)

                        --recordTypeTriple =
                        --    Triple fqn IsA (Node Type)
                        fieldTriples =
                            fields
                                |> List.map
                                    (\field ->
                                        let
                                            subjectFqn =
                                                FQName packageName (List.append moduleName [ typeName ]) field.name

                                            fieldTriple =
                                                case field.tpe of
                                                    Reference _ typeFqn _ ->
                                                        Triple subjectFqn IsA (FQN typeFqn)

                                                    _ ->
                                                        Triple subjectFqn IsA (Other "Anonymous")
                                        in
                                        [ Triple recordTriple.subject Contains (FQN subjectFqn)
                                        , Triple subjectFqn IsA (Node Field)
                                        , fieldTriple
                                        ]
                                    )
                    in
                    --recordTriple :: recordTypeTriple :: (List.concat fieldTriples)
                    recordTriple :: List.concat fieldTriples

                Type.TypeAliasDefinition _ (Type.Reference _ aliasFQN _) ->
                    [ Triple fqn IsA (Node Type)
                    , Triple fqn IsA (FQN aliasFQN)
                    ]

                Type.CustomTypeDefinition _ accessControlledCtors ->
                    let
                        constructorTriples =
                            case accessControlledCtors |> withPublicAccess of
                                Just ctors ->
                                    ctors
                                        |> List.map
                                            (\constructor ->
                                                case constructor of
                                                    Constructor _ namesAndTypes ->
                                                        namesAndTypes
                                                            |> List.filterMap
                                                                (\( _, tipe ) ->
                                                                    case tipe of
                                                                        Reference _ tipeFQN _ ->
                                                                            Just (Triple fqn Uses (FQN tipeFQN))

                                                                        _ ->
                                                                            Nothing
                                                                )
                                            )
                                        |> List.concat

                                Nothing ->
                                    []
                    in
                    Triple fqn IsA (Node Type) :: constructorTriples

                _ ->
                    []
    in
    triples


nodeTypeToString : NodeType -> String
nodeTypeToString node =
    case node of
        Record ->
            "Record"

        Field ->
            "Field"

        Type ->
            "Type"

        Function ->
            "Function"


verbToString : Verb -> String
verbToString verb =
    case verb of
        IsA ->
            "isA"

        Contains ->
            "contains"

        Uses ->
            "uses"
