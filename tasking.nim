# thanks to Elegantbeef for helping

echo " ------- toplevel: Begin -------- "

import std/strformat



type
    ContextRef = ref object
        oid : int
        started : bool
        remaining : int
        ticker : int
        callpath : seq[int]

var
    ctx = ContextRef()

type
    Task = iterator (ticker: int)

var
    next_iter : array[2, Task]


iterator a1(ticker: int) {.closure.} =
    echo fmt"a1: A {ctx.ticker=} {ctx.oid=}"
    yield
    echo fmt"a1: B {ctx.ticker=} {ctx.oid=}"
    yield
    echo fmt"a1: C {ctx.ticker=} {ctx.oid=}"
    yield
    echo fmt"a1: D {ctx.ticker=} {ctx.oid=}"
    yield

iterator a2(ticker: int) {.closure.} =
    echo fmt"a2: A2 {ctx.ticker=} {ctx.oid=}"
    yield
    echo fmt"a2: B2 {ctx.ticker=} {ctx.oid=}"
    yield



proc runTasks(tasks: varargs[Task]):int =
    if not ctx.started:
        ctx.remaining = tasks.len+1
        ctx.ticker = 0
        ctx.started = true
        for assign in 0..<tasks.len:
            next_iter[assign] = tasks[assign]

    ctx.oid = ctx.ticker mod tasks.len

    if finished(next_iter[ctx.oid]):
        dec ctx.remaining

    next_iter[ctx.oid](ctx.ticker)
    inc(ctx.ticker)
    return ctx.remaining


proc setup():void {.exportc.} =
    echo "setup: Begin"
    ctx.ticker = 0
    ctx.remaining = 0
    ctx.started = false
    echo "setup: End"

var i:int

when defined(reactor):
    proc loop():void {.exportc.} =
        if runTasks(a1,a2)>0:
            echo(fmt"{ctx.remaining=}")

else:
    proc loop():int =
        i = 0
        while runTasks(a1,a2)>0:
            echo(fmt"{ctx.remaining=}")
            i += 1
            if i > 10:
                break
        return 0



echo " ------- toplevel: End -------- "

when defined(wasi):

    proc NimMain {.importC: "NimMain"}



    when defined(reactor):


        proc def_start(): void {.exportc:"_start".} =
            echo "WASI-reactor _start"
            once: NimMain()
            setup()
            # now the polyfill will bind requestAnimationFrame to loop()
            # https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame

    else:
        proc main(argc: cint, argv: ptr UncheckedArray[cstring]): cint {.exportC:"main".} =
            echo "WASI main()"
            once: NimMain()
            setup()

            # this one should be called repeatably by wasi polyfill.
            while loop()>0:
                discard
else:
    echo "main startup"
    setup()
    while loop()>0:
        discard



