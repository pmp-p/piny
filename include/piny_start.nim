echo " ------- toplevel: End -------- "

when defined(wasi):

    proc NimMain {.importC: "NimMain"}

    when defined(reactor):

        proc def_start(): void {.exportc:"_start".} =
            echo "WASI-reactor _start"
            when defined(wasi):
                once: NimMain()
            setup()
            # now the polyfill will bind requestAnimationFrame to loop()
            # https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame

    else:
        proc main(argc: cint, argv: ptr UncheckedArray[cstring]): cint {.exportC:"main".} =

            echo "WASI startup"
            setup()

            # this one should be called repeatably by wasi polyfill.
            while loop()>0:
                discard
else:
    echo "main startup"
    setup()
    while loop()>0:
        discard

