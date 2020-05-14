```@meta
CurrentModule = Coluna.MathProg
DocTestSetup = quote
    using Coluna.MathProg
end
```

# Formulation

## Variable

```@docs
getperencost
getcurcost
setcurcost!
getperenlb
getcurlb
setcurlb!
getperenub
getcurub
setcurub!
```

## Constraint

```@docs
getperenrhs
getcurrhs
setcurrhs!
```

## Attributes Variable and constraint

```@docs
getperenkind
getcurkind
setcurkind!
getperensense
getcursense
setcursense!
getperenincval
getcurincval
setcurincval!
isperenactive
iscuractive
activate!
deactivate!
isperenexplicit
iscurexplicit
```

