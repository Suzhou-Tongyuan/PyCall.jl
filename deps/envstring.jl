mutable struct EnvString <: AbstractString
    _get :: Function
    _src :: Ptr{UInt8}
    function EnvString(get)
        this = new()
        this._get = get
        this._src = convert(Ptr{UInt8}, C_NULL)
        return this
    end
end


Base.show(io::IO, envstr::EnvString) = print(io, getsrc(envstr))
Base.ncodeunits(envstr::EnvString) = ncodeunits(getsrc(envstr))
Base.isvalid(envstr::EnvString) = isvalid(getsrc(envstr))
Base.iterate(envstr::EnvString) = iterate(getsrc(envstr))
Base.iterate(envstr::EnvString, state::Integer) = iterate(getsrc(envstr), state)
Base.String(envstr::EnvString) = getsrc(envstr)



function getsrc(envstr::EnvString)
    envstr._src != C_NULL && return unsafe_string(envstr._src)
    envstr._src = pointer(String(envstr._get()))
    # @show envstr._get, unsafe_string(envstr._src)
    return unsafe_string(envstr._src)
end