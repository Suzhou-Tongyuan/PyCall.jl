const source_code = read(joinpath(@__DIR__, "find_libpython.py"), String)

function cmd_find_libpython(python, options, PYCALL_DEBUG_BUILD::Bool)
    if PYCALL_DEBUG_BUILD
        pipeline(IOBuffer(source_code), `$python -c 'import sys;exec(sys.stdin.read())' $options --verbose`)
    else
        pipeline(IOBuffer(source_code), `$python -c 'import sys;exec(sys.stdin.read())' $options`)
    end
end
