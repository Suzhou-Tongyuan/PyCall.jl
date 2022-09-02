include("envstring.jl")
include("buildutils.jl")
include("depsutils.jl")
# add Pkg VersionParsing and Conda if use pyjulia
import Conda, Libdl

struct UseCondaPython <: Exception end

function whichfirst(args...)
    for x in args
        if Sys.which(x) !== nothing
            return x
        end
    end
    return ""
end

# get the environment variable at runtime

function getenv_python()
    python = try
        let py = get(ENV, "PYTHON",
                     (Sys.isunix() && !Sys.isapple()) ?
                     whichfirst("python3", "python") : "Conda"),
            vers = isempty(py) || py == "Conda" ? v"0.0" : vparse(pyconfigvar(py,"VERSION","0.0"))
            if vers < v"2.7"
                if isempty(py) || py == "Conda"
                    throw(UseCondaPython())
                else
                    error("Python version $vers < 2.7 is not supported")
                end
            end

            # check word size of Python via sys.maxsize, since a common error
            # on Windows is to link a 64-bit Julia to a 32-bit Python.
            pywordsize = parse(UInt64, pysys(py, "maxsize")) > (UInt64(1)<<32) ? 64 : 32
            if pywordsize != Sys.WORD_SIZE
                error("$py is $(pywordsize)-bit, but Julia is $(Sys.WORD_SIZE)-bit")
            end

            py
        end
    catch e1
        if isa(e1, UseCondaPython)
            @info string("Using the Python distribution in the Conda package by default.\n",
                 "To use a different Python version, set ENV[\"PYTHON\"]=\"pythoncommand\" and re-run Pkg.build(\"PyCall\").")
        else
            @info string("No system-wide Python was found; got the following error:\n",
                  "$e1\nusing the Python distribution in the Conda package")
        end
        abspath(Conda.PYTHONDIR, "python" * (Sys.iswindows() ? ".exe" : ""))
    end
    return String(python)
end

const python = EnvString(getenv_python)


const use_conda = false
# if use_conda
#     Conda.add("numpy")
# end

function getenv_libpython()
    _, libpy_name = find_libpython_deps(String(python))
    return libpy_name
end

function getenv_pyprogramname()
    programname = pysys(String(python), "executable")
    return programname
end

function getenv_pythonhome()
    PYTHONHOME = if !haskey(ENV, "PYTHONHOME") || use_conda
        pythonhome_of(String(python))
    else
        ENV["PYTHONHOME"]
    end
    return PYTHONHOME
end


const libpython = EnvString(getenv_libpython)
const pyprogramname = EnvString(getenv_pyprogramname)
const pyversion_build = v"3.7.13" # relocate?
const PYTHONHOME = EnvString(getenv_pythonhome)

"True if we are using the Python distribution in the Conda package."
const refconfig_conda = Ref(use_conda)
