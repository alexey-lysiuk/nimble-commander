// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <memory>
#include <functional>
#include <atomic>
#include "dispatch_cpp.h"
#include "spinlock.h"
#include "algo.h"

namespace nc::base {

// TODO: unit tests???
class SerialQueue
{
public:
    SerialQueue(const char *_label = nullptr);

    /**
     * Will invoke Stop() and Wait() inside.
     */
    ~SerialQueue();

    /**
     * Starts _f asynchronously in this queue.
     */
    template <class T>
    void Run(T _f) const;

    /**
     * Raises IsStopped() flag so currently running tasks can caught it.
     * Will hold this flag more until queue became dry, then will automaticaly lower this flag.
     */
    void Stop();

    /**
     * Synchronously waits until queue became dry, if queue is not Empty().
     * Note that OnDry() will be called before Wait() will return.
     */
    void Wait();

    /**
     * Returns value of the stop flag.
     */
    bool IsStopped() const;

    /**
     * Returns count of block commited into queue, including currently running block, if any.
     * Zero returned length means that queue is dry.
     */
    int Length() const noexcept;

    /**
     * Actually returns Length() == 0. Just a syntax sugar.
     */
    bool Empty() const noexcept;

    /**
     * Sets handler to be called when queue becomes dry (no blocks are commited or running).
     * Stop flag will be lowered automatically anyway.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~SerialQueue().
     * Reentrant.
     */
    void SetOnDry(std::function<void()> _on_dry);

    /**
     * Sets handler to be called when queue becomes wet (when block is commited to run in it).
     * Might be called from undefined background thread.
     * Reentrant.
     */
    void SetOnWet(std::function<void()> _on_wet);

    /**
     * Sets handler to be called very time when queue length is changed.
     * Might be called from undefined background thread.
     * Will be called even on Wait() inside ~SerialQueue().
     * Reentrant.
     */
    void SetOnChange(std::function<void()> _on_change);

private:
    SerialQueue(const SerialQueue &) = delete;
    void operator=(const SerialQueue &) = delete;
    void Increment() const;
    void Decrement() const;
    void FireDry() const;
    void FireWet() const;
    void FireChanged() const;
    dispatch_queue_t m_Queue;
    mutable std::atomic_int m_Length = {0};
    mutable std::atomic_bool m_Stopped = {false};
    mutable nc::spinlock m_CallbackLock;
    std::shared_ptr<std::function<void()>> m_OnDry;
    std::shared_ptr<std::function<void()>> m_OnWet;
    std::shared_ptr<std::function<void()>> m_OnChange;
};

template <class T>
void SerialQueue::Run(T _f) const
{
    struct Ctx {
        T f;
        const SerialQueue *q;
    };
    Increment();
    dispatch_async_f(m_Queue, new Ctx{std::move(_f), this}, [](void *_p) {
        Ctx *context = static_cast<Ctx *>(_p);
        auto cleanup = at_scope_end([context] { delete context; });
        context->f();
        context->q->Decrement();
    });
}

} // namespace nc::base
