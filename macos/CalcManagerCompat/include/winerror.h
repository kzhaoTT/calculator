// Cross-platform compatibility shim for Windows winerror.h on macOS.
#pragma once

#include <cstdint>

#ifndef S_OK
#define S_OK ((int32_t)0x0)
#endif
#ifndef S_FALSE
#define S_FALSE ((int32_t)0x1)
#endif
#ifndef E_FAIL
#define E_FAIL ((int32_t)0x80004005)
#endif
#ifndef E_INVALIDARG
#define E_INVALIDARG ((int32_t)0x80070057)
#endif
#ifndef E_OUTOFMEMORY
#define E_OUTOFMEMORY ((int32_t)0x8007000E)
#endif
#ifndef E_POINTER
#define E_POINTER ((int32_t)0x80004003)
#endif
#ifndef E_UNEXPECTED
#define E_UNEXPECTED ((int32_t)0x8000FFFF)
#endif
#ifndef E_BOUNDS
#define E_BOUNDS ((int32_t)0x8000000B)
#endif
#ifndef E_ACCESSDENIED
#define E_ACCESSDENIED ((int32_t)0x80070005)
#endif
