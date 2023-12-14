#/bin/bash

alias julia='/Applications/Julia-1.9.app/Contents/Resources/julia/bin/julia'

FILE="test/.222-revise-exit-code"

clear
julia --project=@. -e "import Pkg; Pkg.instantiate(); Pkg.test(; test_args = [\"$@\"]);"
while test -f "$FILE"
do
    clear
    rm $FILE
    julia --project=@. -e "import Pkg; Pkg.instantiate(); Pkg.test(; test_args = [\"$@\"]);"
done