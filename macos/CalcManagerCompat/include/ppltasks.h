// Cross-platform minimal concurrency::task shim for CalcManager on macOS.
#pragma once

#include <functional>
#include <type_traits>
#include <utility>

namespace concurrency
{
    template <typename T>
    class task
    {
    public:
        task() : m_value{} {}
        explicit task(T value) : m_value(std::move(value)) {}

        T get() const
        {
            return m_value;
        }

        template <typename Func>
        auto then(Func&& func) const -> task<std::invoke_result_t<Func, T>>
        {
            using ResultType = std::invoke_result_t<Func, T>;
            return task<ResultType>(func(m_value));
        }

    private:
        T m_value;
    };

    template <typename T>
    inline task<T> task_from_result(T value)
    {
        return task<T>(std::move(value));
    }
}
