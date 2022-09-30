include("envstring.jl")
const python = EnvString("PYTHON", "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python.exe")
const pyversion_build = v"3.9.7"

module BuildTimeUtils
    if isdefined(Base, :Experimental)
        # Julia 1.2
        if isdefined(Base.Experimental, Symbol("@optlevel"))
            @eval Base.Experimental.@optlevel 1
        end

        if isdefined(Base.Experimental, Symbol("@compiler_options"))
            @eval Base.Experimental.@compiler_options infer=no compile=min optimize=0
        end
    end
    include(joinpath(dirname(@__FILE__), "..", "deps","buildutils.jl"))
    include(joinpath(dirname(@__FILE__), "..", "deps","depsutils.jl"))
end

const libpython = EnvString("PYCALL_LIBPYTHON") do
    if "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python.exe" == python
        "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python39.dll"
    else
        BuildTimeUtils.find_libpython(python)[2]
    end
end

const pyprogramname = EnvString("PYCALL_PYPROGRAM") do
    if "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python39.dll" == libpython
        "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python.exe"
    else
        BuildTimeUtils.pysys(python, "executable")
    end
end

const PYTHONHOME = EnvString("PYTHONHOME") do
    if "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3\\python39.dll" == libpython
        "C:\\Users\\Public\\TongYuan\\.julia\\conda\\3"
    else
        BuildTimeUtils.pythonhome_of(python)
    end
end

"True if we are using the Python distribution in the Conda package."
const _env_conda = EnvString("PYCALL_USECONDA", "true")
conda = parse(Bool, String(_env_conda))
