from julia.core import enable_debug
enable_debug()
# from julia import Main

# from julia.api import LibJulia, JuliaInfo

# api = LibJulia.from_juliainfo(JuliaInfo.load())

# ret = api.jl_eval_string(b"Int64(1 + 2)")
# print("test", int(api.jl_unbox_int64(ret)))


from julia.api import LibJulia, JuliaInfo
# api = LibJulia.from_juliainfo(JuliaInfo.load())
api = LibJulia.from_juliainfo(JuliaInfo.load("julia"))

from julia.options import JuliaOptions

PYCALL_PKGID = """\
Base.PkgId(Base.UUID("438e738f-606a-5dbb-bf0a-cddfbfd45ab0"), "PyCall")"""

api.init_julia(JuliaOptions())

ret = api.jl_eval_string(b"Int64(1 + 2)")
print("test", int(api.jl_unbox_int64(ret)))

ret = api.jl_eval_string("const PyCall = Base.require({0}); print(1)".format(PYCALL_PKGID).encode('utf-8'))
str(api.jl_exception_occurred())
