module PyJulia
using PyCall

const PyJVCodeFile = joinpath((@__DIR__), "jv.py")
const PyJVCode = read(PyJVCodeFile, String)

const _store_string_symbols = Dict{String, Symbol}()
const _store_symbol_pystrings = Dict{Symbol, PyObject}()

# caching the conversion from Julia String to Symbol
function attr_name_to_symbol(s::String)::Symbol
    get!(_store_string_symbols, s) do
        v = Symbol(s)
        _store_string_symbols[s] = v
        return v
    end
end

# caching the conversion from Julia Symbol to PyObject
function attr_symbol_to_pystring(s::Symbol)::PyObject
    get!(_store_symbol_pystrings, s) do
        v = PyObject(string(s))
        _store_symbol_pystrings[s] = v
        return v
    end
end

"""
A simple wrapper of PyCall PyObject to support ORM for Python objects:
0. callable
1. getindex, setindex!
2. getproperty, setproperty!
3. length
4. repr/string/show
"""
struct Py
    o::PyObject
end

mutable struct RequiredFromPythonAPIStruct
    JV::Py
    _NoConv::Py
    class::Py  # the 'type' object in Python
    next::Py
    none::Py
    iter::Py
    len::Py
    getattr::Py
    setattr::Py
    # modules
    operator::Py
    # buultin datatypes
    dict::Py
    object::Py

    bytearray::Py
    tuple::Py
    int::Py
    float::Py
    str::Py
    bool::Py
    ndarray::Py
    complex::Py

    none_wrap::Py
    true_wrap::Py
    false_wrap::Py
    RequiredFromPythonAPIStruct() = new()
end

const MyPyAPI = RequiredFromPythonAPIStruct()

PyObject(py::Py) = getfield(py, :o)
PyPtr(py::Py) = PyCall.PyPtr(PyObject(py))

@noinline function (py::Py)(args...; kwargs...)
    d = Pair{Symbol, PyObject}[]
    for (k, v) in kwargs
        push!(d, k=>PyObject(v))
    end
    Py(PyCall.pycall(PyObject(py), PyObject, (PyObject(arg) for arg in args)...; d...))
end

@noinline function (py::Py)(args::Py...)
    Py(PyCall.pycall(PyObject(py), PyObject, (PyObject(arg) for arg in args)...))
end


@noinline function _mk_tuple(args)
    lst = PyCall.PyVector(PyObject[])
    for arg in args
        push!(lst, PyObject(arg))
    end
    return MyPyAPI.tuple(Py(PyObject(lst)))
end

@noinline Base.getproperty(x::Py, s::Symbol)::Py = MyPyAPI.getattr(x, Py(attr_symbol_to_pystring(s)))
@noinline Base.setproperty!(x::Py, s::Symbol, v::Py)::Py = MyPyAPI.setattr(x, Py(attr_symbol_to_pystring(s)), v)
@noinline Base.getindex(x::Py, @nospecialize(args::Py...))::Py =
    if length(args) == 1
        MyPyAPI.operator.getitem(x, args[1])
    else
        MyPyAPI.operator.getitem(x, _mk_tuple(args))
    end

@noinline Base.setindex!(x::Py, v::Py, @nospecialize(args::Py...))::Py =
    if length(args) == 1
        MyPyAPI.operator.setitem(x, args[1], v)
        v
    else
        MyPyAPI.operator.setitem(x, _mk_tuple(args), v)
        v
    end

@noinline Base.length(x::Py)::Clonglong = convert(Clonglong, reasonable_unbox(MyPyAPI.len(x)))

@noinline Base.show(io::IO, x::Py) =
    let repr = PyCall.pystring(PyObject(x))
        print(io, "Py($(repr))")
    end


@noinline function init_pyjulia()::PyObject
    PyCall.py"""
    from __future__ import annotations
    import sys
    from types import ModuleType

    _pyjulia_core = ModuleType("_pyjulia_core")
    sys.modules["_pyjulia_core"] = _pyjulia_core
    _pyjulia_core.__dict__.update(globals())

    def _load_source(src_code, filename):
        exec(compile(src_code, filename, 'exec', flags=annotations.compiler_flag), _pyjulia_core.__dict__, _pyjulia_core.__dict__)
    """

    _pyjulia_core = py"_pyjulia_core"
    _load_source = py"_load_source"
    ns = PyDict{String, PyObject}(_pyjulia_core."__dict__")

    _load_source(PyJVCode, PyJVCodeFile)

    MyPyAPI.JV = Py(ns["JV"])
    MyPyAPI._NoConv = Py(ns["_NoConv"])
    MyPyAPI.class = Py(PyCall.pybuiltin("type"))
    MyPyAPI.next = Py(PyCall.pybuiltin("next"))
    MyPyAPI.none = Py(PyCall.pybuiltin("None"))
    MyPyAPI.iter = Py(PyCall.pybuiltin("iter"))
    MyPyAPI.len = Py(PyCall.pybuiltin("len"))
    MyPyAPI.getattr = Py(PyCall.pybuiltin("getattr"))
    MyPyAPI.setattr = Py(PyCall.pybuiltin("setattr"))
    MyPyAPI.dict = Py(PyCall.pybuiltin("dict"))
    MyPyAPI.object = Py(PyCall.pybuiltin("object"))
    MyPyAPI.tuple = Py(PyCall.pybuiltin("tuple"))
    MyPyAPI.int = Py(PyCall.pybuiltin("int"))
    MyPyAPI.float = Py(PyCall.pybuiltin("float"))
    MyPyAPI.str = Py(PyCall.pybuiltin("str"))
    MyPyAPI.bool = Py(PyCall.pybuiltin("bool"))
    MyPyAPI.ndarray = Py(PyCall.pyimport("numpy")."ndarray")
    MyPyAPI.bytearray = Py(PyCall.pybuiltin("bytearray"))
    MyPyAPI.complex = Py(PyCall.pybuiltin("complex"))
    MyPyAPI.operator = Py(PyCall.pyimport("operator"))
    MyPyAPI.none_wrap = Py(PyCall.pycall(ns["_NoConv"], PyObject, PyObject(nothing)))
    MyPyAPI.true_wrap = Py(PyCall.pycall(ns["_NoConv"], PyObject, PyObject(true)))
    MyPyAPI.false_wrap = Py(PyCall.pycall(ns["_NoConv"], PyObject, PyObject(false)))
    return _pyjulia_core
end


function classof(x::Union{Py, PyObject})::Py
    Py(PyCall.pytypeof(PyObject(x)))
end

function is_type_exact(x::Union{Py, PyObject}, t::Union{Py, PyObject})::Bool
    PyCall.PyPtr(PyCall.pytypeof(PyObject(x))) === PyCall.PyPtr(PyObject(t))
end

@inline function box_julia(val::Any)::Py
    jv = MyPyAPI.JV()
    MyPyAPI.object.__setattr__(
        jv,
        Py(attr_symbol_to_pystring(:__jl__)),
        Py(PyCall.pyjlwrap_new(val))
    )

    return jv
end

@noinline function unbox_julia_tuple(x::Py)
    n = length(x)
    elements = Any[]
    for i = 0:n-1
        item = x[Py(PyObject(i))]::Py
        push!(elements, reasonable_unbox(item))
    end
    return Core.tuple(elements...)
end

function unbox_julia(x::Py)
    return PyObject(x).__jl__
end

@noinline function reasonable_unbox(x::Py)
    if is_type_exact(x, MyPyAPI.JV)
        return PyObject(x).__jl__
    end
    if is_type_exact(x, MyPyAPI.int)
        return convert(Clonglong, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.float)
        return convert(Cdouble, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.str)
        return convert(String, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.bool)
        return convert(Bool, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.complex)
        return convert(ComplexF64, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.tuple)
        return unbox_julia_tuple(x)
    elseif PyPtr(x) === PyPtr(MyPyAPI.none)
        return nothing
    elseif is_type_exact(x, MyPyAPI.bytearray)
        return convert(PyArray, PyObject(x))
    elseif is_type_exact(x, MyPyAPI.ndarray)
        o = PyObject(x)
        if startswith(o."dtype".name, "str")
            return convert(Array{String}, o)
        end
        # TODO: check valid typecode
        return convert(PyArray, o)
    else
        error("unbox_julia: unhandled Python type: ", classof(x))
    end
end


const SupportedElementTypes = Union{
    Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64,
    Float16, Float32, Float64,
    ComplexF16, ComplexF32, ComplexF64, Bool
}

@noinline function _box_tuple(@nospecialize(x::Tuple))::Py
    n = length(x)
    args = PyObject[]
    for i = 1:n
        push!(args, PyObject(reasonable_box(x[i])))
    end
    return _mk_tuple(args)
end

@noinline function reasonable_box_slow_path(x::Any)::Py

    if x isa Integer
        return Py(PyObject(x))
    end

    if x isa AbstractFloat
        return Py(PyObject(Cdouble(x)))
    end

    if x isa Complex
        return Py(PyObject(ComplexF64(x)))
    end

    if x isa AbstractString
        return Py(PyObject(String(x)))
    end

    return box_julia(x)
end

function reasonable_box(x::Any)::Py
    # fast path
    if x === nothing
        return MyPyAPI.none
    end
    if x isa Union{Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64}
        return Py(PyObject(x))
    end
    if x isa Union{Float16, Float32, Float64}
        return Py(PyObject(Cdouble(x)))
    end
    if x isa String
        return Py(PyObject(x))
    end
    if x isa Bool
        return Py(PyObject(x))
    end
    if x isa Union{ComplexF16, ComplexF32, ComplexF64}
        return Py(PyObject(ComplexF64(x)))
    end

    x isa BitArray && return box_julia(x)

    if x isa AbstractArray
        elty = eltype(typeof(x))
        elty <: SupportedElementTypes || return box_julia(x)
        if x isa StridedArray
            return Py(PyObject(x))
        else
            return Py(PyObject(collect(x)))
        end
    end

    if x isa Tuple
        return _box_tuple(x)
    end

    # slow path
    return reasonable_box_slow_path(x)
end



function jl_call(self::PyObject, args::PyObject, kwargs::PyObject)::PyObject
    let args = Py(args).__py__,
        kwargs = Py(kwargs).__py__,
        self = Py(self)

        if !is_type_exact(self, MyPyAPI.JV)
            error("The first argument must be a Julia object.")
        end

        if !is_type_exact(args, MyPyAPI.tuple)
            error("JV.__call__: args must be a tuple, got ($(classof(args))).")
        end

        if !is_type_exact(kwargs, MyPyAPI.dict)
            error("JV.__call__: kwargs must be a dict.")
        end

        nargs = length(args)
        nkwargs = length(kwargs)
        jlargs = Any[]
        for i = 0:nargs-1
            arg = args[Py(PyObject(i))]::Py
            jlarg = reasonable_unbox(arg)
            push!(jlargs, jlarg)
        end

        jlkwargs = Pair{Symbol, Any}[]
        kwargs_iter = MyPyAPI.iter(kwargs)
        for _ = 0:nkwargs-1
            k = MyPyAPI.next(kwargs_iter)
            sym = Symbol(convert(String, PyObject(k)))
            v = reasonable_unbox(kwargs[k])
            push!(jlkwargs, sym => v)
        end

        jv = unbox_julia(self)
        return PyObject(MyPyAPI._NoConv(reasonable_box(jv(jlargs...; jlkwargs...))))
    end
end



function jl_getattr(self::PyObject, attr::PyObject)::PyObject
    let self = Py(self),
        attr = Py(attr).__py__

        jv = unbox_julia(self)
        sym = attr_name_to_symbol(convert(String, PyObject(attr)))
        return PyObject(MyPyAPI._NoConv(reasonable_box(getproperty(jv, sym))))
    end
end


function jl_setattr(self::PyObject, attr::PyObject, val::PyObject)::PyObject
    let self = Py(self),
        attr = Py(attr).__py__,
        val = Py(val).__py__

        jv = unbox_julia(self)
        sym = attr_name_to_symbol(convert(String, PyObject(attr)))
        setproperty!(jv, sym, reasonable_unbox(val))
        return PyObject(MyPyAPI.none_wrap)
    end
end


function jl_getitem(self::PyObject, item::PyObject)::PyObject
    let self = Py(self),
        item = Py(item).__py__

        v = if is_type_exact(item, MyPyAPI.tuple)
            reasonable_box(
                getindex(unbox_julia(self), reasonable_unbox(item)...))::Py
        else
            reasonable_box(
                getindex(unbox_julia(self), reasonable_unbox(item)))::Py
        end
        PyObject(MyPyAPI._NoConv(v))
    end
end

function jl_setitem(self::PyObject, item::PyObject, val::PyObject)::PyObject
    # Python multi-indexing is translated to indexing using a tuple.
    # So we do multi-indexing if `item` is a tuple.
    let self = Py(self),
        item = Py(item).__py__,
        val = Py(val).__py__

        if is_type_exact(item, MyPyAPI.tuple)
            setindex!(unbox_julia(self), reasonable_unbox(val), reasonable_unbox(item)...)
        else
            setindex!(unbox_julia(self), reasonable_unbox(val), reasonable_unbox(item))
        end
        return PyObject(MyPyAPI.none_wrap)
    end
end

function jl_add(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) + reasonable_unbox(other))))
    end
end

function jl_sub(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) - reasonable_unbox(other))))
    end
end

function jl_mul(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) .* reasonable_unbox(other))))
    end
end

function jl_matmul(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) * reasonable_unbox(other))))
    end
end

function jl_truediv(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) / reasonable_unbox(other))))
    end
end

function jl_floordiv(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(div(unbox_julia(self), reasonable_unbox(other)))))
    end
end

function jl_mod(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(Base.mod(unbox_julia(self), reasonable_unbox(other)))))
    end
end

function jl_pow(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) ^ reasonable_unbox(other))))
    end
end

function jl_lshift(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) << reasonable_unbox(other))))
    end
end

function jl_rshift(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) >> reasonable_unbox(other))))
    end
end

function jl_bitor(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) | reasonable_unbox(other))))
    end
end

function jl_bitxor(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) ⊻ reasonable_unbox(other))))
    end
end

function jl_bitand(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) & reasonable_unbox(other))))
    end
end

function jl_eq(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) == reasonable_unbox(other))))
    end
end

function jl_ne(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) != reasonable_unbox(other))))
    end
end

function jl_lt(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) < reasonable_unbox(other))))
    end
end

function jl_le(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) <= reasonable_unbox(other))))
    end
end

function jl_gt(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) > reasonable_unbox(other))))
    end
end

function jl_ge(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(unbox_julia(self) >= reasonable_unbox(other))))
    end
end

function jl_contains(self::PyObject, other::PyObject)::PyObject
    let self = Py(self),
        other = Py(other).__py__

        return PyObject(MyPyAPI._NoConv(reasonable_box(reasonable_unbox(other) in unbox_julia(self))))
    end
end

function jl_invert(self::PyObject)::PyObject
    let self = Py(self)

        return PyObject(MyPyAPI._NoConv(reasonable_box(~unbox_julia(self))))
    end
end

function jl_bool(self::PyObject)::PyObject
    test = let self = Py(self)
        # TODO: fast path
        o = unbox_julia(self)
        if o isa Number
            o != 0
        elseif (o isa AbstractArray || o isa AbstractDict || o isa AbstractSet || o isa AbstractString)
            !isempty(o)
        else
            # return `true` is the default semantics of a Python object
            true
        end
    end
    if test
        return PyObject(MyPyAPI.true_wrap)
    else
        return PyObject(MyPyAPI.false_wrap)
    end
end

function jl_pos(self::PyObject)::PyObject
    let self = Py(self)

        return PyObject(MyPyAPI._NoConv(reasonable_box(+unbox_julia(self))))
    end
end

function jl_neg(self::PyObject)::PyObject
    let self = Py(self)

        return PyObject(MyPyAPI._NoConv(reasonable_box(-unbox_julia(self))))
    end
end

function jl_abs(self::PyObject)::PyObject
    let self = Py(self)

        return PyObject(MyPyAPI._NoConv(reasonable_box(abs(unbox_julia(self)))))
    end
end

function jl_hash(self::PyObject)::PyObject
    let self = Py(self)
        return PyObject(MyPyAPI._NoConv(Py(PyObject(
            hash(unbox_julia(self)) % Int64
        ))))
    end
end

function jl_repr(self::PyObject)::PyObject
    let self = Py(self)
        address = reinterpret(UInt, PyPtr(self))
        s = "<JV(" * repr(unbox_julia(self)) * ") at $(repr(address))>"
        return PyObject(MyPyAPI._NoConv(Py(PyObject(s))))
    end
end

function jl_display(self::PyObject)::PyObject
    let self = Py(self)
        old_stdout = stdout
        rd, wr = redirect_stdout()
        try
            show(wr, "text/plain", unbox_julia(self))
        finally
            try
                close(wr)
            catch
            end
            redirect_stdout(old_stdout)
        end
        return PyObject(MyPyAPI._NoConv(Py(PyObject(read(rd, String)))))
    end
end

@noinline function setup_jv(jv_module::PyObject)::Nothing
    jv_module.__jl_invoke__ = jl_call
    jv_module.__jl_getattr__ = jl_getattr
    jv_module.__jl_setattr__ = jl_setattr
    jv_module.__jl_getitem__ = jl_getitem
    jv_module.__jl_setitem__ = jl_setitem
    jv_module.__jl_add__ = jl_add
    jv_module.__jl_sub__ = jl_sub
    jv_module.__jl_mul__ = jl_mul
    jv_module.__jl_matmul__ = jl_matmul
    jv_module.__jl_truediv__ = jl_truediv
    jv_module.__jl_floordiv__ = jl_floordiv
    jv_module.__jl_mod__ = jl_mod
    jv_module.__jl_pow__ = jl_pow
    jv_module.__jl_lshift__ = jl_lshift
    jv_module.__jl_rshift__ = jl_rshift
    jv_module.__jl_bitor__ = jl_bitor
    jv_module.__jl_bitxor__ = jl_bitxor
    jv_module.__jl_bitand__ = jl_bitand
    jv_module.__jl_eq__ = jl_eq
    jv_module.__jl_ne__ = jl_ne
    jv_module.__jl_lt__ = jl_lt
    jv_module.__jl_le__ = jl_le
    jv_module.__jl_gt__ = jl_gt
    jv_module.__jl_ge__ = jl_ge
    jv_module.__jl_contains__ = jl_contains
    jv_module.__jl_invert__ = jl_invert
    jv_module.__jl_bool__ = jl_bool
    jv_module.__jl_pos__ = jl_pos
    jv_module.__jl_neg__ = jl_neg
    jv_module.__jl_abs__ = jl_abs
    jv_module.__jl_hash__ = jl_hash
    jv_module.__jl_repr__ = jl_repr
    jv_module._jl_repr_pretty_ = jl_display
    nothing
end

@noinline function evaluate(s::String)
    Base.eval(Main::Module, Meta.parseall(s))
end

@noinline function setup_basics(_pyjulia_core::PyObject)::Nothing
    ns = Py(_pyjulia_core)
    ns.Base = reasonable_box(Base)
    ns.Main = reasonable_box(Main)
    ns.evaluate = reasonable_box(evaluate)
    nothing
end


function init()
    os = pyimport("os")
    empty!(_store_string_symbols)
    empty!(_store_symbol_pystrings)
    _pyjulia_core = init_pyjulia()::PyObject
    setup_jv(_pyjulia_core)
    setup_basics(_pyjulia_core)
    Py(os."environ")[reasonable_box("PYJULIA_CORE")] = reasonable_box("pycall")
    nothing
end

precompile(reasonable_box, (Int, ))
precompile(reasonable_box, (Cdouble, ))
precompile(reasonable_box, (Nothing, ))
precompile(reasonable_box, (String, ))
precompile(reasonable_box, (Bool, ))
precompile(reasonable_box, (ComplexF64, ))
precompile(reasonable_box, (Module, ))
precompile(evaluate, (String, ))
precompile(setup_jv, (PyObject, ))
precompile(setup_basics, (PyObject, ))
precompile(jl_call, (PyObject, PyObject, PyObject))
precompile(jl_getattr, (PyObject, PyObject))
precompile(jl_setattr, (PyObject, PyObject, PyObject))
precompile(init, ())

end