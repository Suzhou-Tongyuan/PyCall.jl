#
from __future__ import annotations
import typing

__jl_invoke__: typing.Callable[[JV, _NoConv, _NoConv], _NoConv]
__jl_getattr__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_setattr__: typing.Callable[[JV, _NoConv, _NoConv], _NoConv]
__jl_getitem__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_setitem__: typing.Callable[[JV, _NoConv, _NoConv], _NoConv]
__jl_add__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_sub__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_mul__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_matmul__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_truediv__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_floordiv__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_mod__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_pow__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_lshift__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_rshift__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_bitor__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_bitxor__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_bitand__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_eq__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_ne__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_lt__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_le__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_gt__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_ge__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_contains__: typing.Callable[[JV, _NoConv], _NoConv]
__jl_invert__: typing.Callable[[JV], _NoConv]
__jl_bool__: typing.Callable[[JV], _NoConv]
__jl_pos__: typing.Callable[[JV], _NoConv]
__jl_neg__: typing.Callable[[JV], _NoConv]
__jl_abs__: typing.Callable[[JV], _NoConv]
__jl_hash__: typing.Callable[[JV], _NoConv]
__jl_repr__: typing.Callable[[JV], _NoConv]
_jl_repr_pretty_: typing.Callable[[JV], _NoConv]

class _NoConv:
    __slots__ = ['__py__']
    def __init__(self, v):
        self.__py__ = v

class JV:
    __slots__ = ["__jl__"]

    def __call__(self, *args, **kwargs):
        return __jl_invoke__(self, _NoConv(args), _NoConv(kwargs)).__py__

    def __getattr__(self, name: str):
        return __jl_getattr__(self, _NoConv(name)).__py__

    def __setattr__(self, name: str, value):
        return __jl_setattr__(self, _NoConv(name), _NoConv(value)).__py__

    def __getitem__(self, key):
        return __jl_getitem__(self, _NoConv(key)).__py__

    def __setitem__(self, key, value):
        __jl_setitem__(self, _NoConv(key), _NoConv(value))

    def __add__(self, other):
        return __jl_add__(self, _NoConv(other)).__py__

    def __sub__(self, other):
        return __jl_sub__(self, _NoConv(other)).__py__

    def __mul__(self, other):
        return __jl_mul__(self, _NoConv(other)).__py__

    def __matmul__(self, other):
        return __jl_matmul__(self, _NoConv(other)).__py__

    def __truediv__(self, other):
        return __jl_truediv__(self, _NoConv(other)).__py__

    def __floordiv__(self, other):
        return __jl_floordiv__(self, _NoConv(other)).__py__

    def __mod__(self, other):
        return __jl_mod__(self, _NoConv(other)).__py__

    def __pow__(self, other):
        return __jl_pow__(self, _NoConv(other)).__py__

    def __lshift__(self, other):
        return __jl_lshift__(self, _NoConv(other)).__py__

    def __rshift__(self, other):
        return __jl_rshift__(self, _NoConv(other)).__py__

    def __or__(self, other):
        return __jl_bitor__(self, _NoConv(other)).__py__

    def __xor__(self, other):
        return __jl_bitxor__(self, _NoConv(other)).__py__

    def __and__(self, other):
        return __jl_bitand__(self, _NoConv(other)).__py__

    def __eq__(self, other):
        return __jl_eq__(self, _NoConv(other)).__py__

    def __ne__(self, other):
        return __jl_ne__(self, _NoConv(other)).__py__

    def __lt__(self, other):
        return __jl_lt__(self, _NoConv(other)).__py__

    def __le__(self, other):
        return __jl_le__(self, _NoConv(other)).__py__

    def __gt__(self, other):
        return __jl_gt__(self, _NoConv(other)).__py__

    def __ge__(self, other):
        return __jl_ge__(self, _NoConv(other)).__py__

    def __contains__(self, other):
        return __jl_contains__(self, _NoConv(other)).__py__

    def __invert__(self):
        return __jl_invert__(self).__py__

    def __bool__(self):
        return __jl_bool__(self).__py__

    def __pos__(self):
        return __jl_pos__(self).__py__

    def __neg__(self):
        return __jl_neg__(self).__py__

    def __abs__(self):
        return __jl_abs__(self).__py__

    def __hash__(self):
        return __jl_hash__(self).__py__

    def __repr__(self):
        return __jl_repr__(self).__py__

    def _repr_pretty_(self, p, cycle):
        p.text(_jl_repr_pretty_(self).__py__ if not cycle else "...")

    def __iter__(self):
        global _jl_iterate
        try:
            jl_iterate = _jl_iterate  # type: ignore
        except NameError:
            from _pyjulia_core import Base  # type: ignore

            jl_iterate = _jl_iterate = Base.iterate

        pair = jl_iterate(self)
        while pair is not None:
            element, state = pair
            yield element
            pair = jl_iterate(self, state)
