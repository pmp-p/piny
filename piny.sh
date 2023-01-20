#!/bin/bash
ROOT=$(realpath $(pwd))
SDKROOT=$(realpath $(dirname $0))
. $SDKROOT/config

NIMROOT=$ROOT/$NIM_VERSION

# -Wl,--no-entry -mexec-model=reactor
# https://github.com/WebAssembly/wasi-sdk/issues/110
# https://github.com/WebAssembly/WASI/issues/13

# exceptions with goto,setjmp
# https://forum.nim-lang.org/t/9720#63935
# --exceptions:quirky
#       =>panic with sysFatal and unhandled exception type report
# --exceptions:goto
#       => OK

reset
export COMPILER_REPLAY

function summary () {

    echo "_________ $NIMROOT $BITS, $1 ______________"
    echo $PATH
    echo python=$(python -V 2>&1)
    echo python3=$(python3 -V 2>&1)
    which clang
    which nim
    which nimble
    echo "COMPILER_REPLAY=$COMPILER_REPLAY"
    echo "____________________________________________________"

}

if echo $0|grep -q piny.sh$
then
    echo installing ...
    mkdir -p $ROOT/bin $ROOT/state $ROOT/cache $ROOT/pkg $BINOUT

    # cannot ln on cross dev
    if [ $SDKROOT = $ROOT ]
    then
        echo "Using source folder $ROOT as SDKROOT"
    else
        cp -rf $SDKROOT/* ./
    fi

    ln -f $ROOT/bin/wasi/clang $ROOT/bin/wasi/clang++

    COMPILERS="nimjs nimwasi nimweb nimemsdk nim32 nim64"
    rm $COMPILERS

    for lnk in $COMPILERS
    do
        mkdir -p $ROOT/cache/$lnk
        if [ -f $ROOT/$lnk ]
        then
            continue
        else
            ln piny.sh $ROOT/$lnk
            chmod +x $ROOT/$lnk

        fi
    done

    if echo $NIM_URL|grep -q ^git$
    then
        if [ -d Nim/bin ]
        then
            echo using local devel version
        else
            echo building Nim devel
            ./get_dev.sh && rm ./get_dev.sh
        fi
    else
        if [ -d $NIM_VERSION ]
        then
            echo -n
        else
            wget -c $NIM_URL
            tar xf ${NIM_VERSION}-linux_*.tar.xz
        fi
    fi

    cat > nimble << END
#!/bin/bash
export NIMBLE_DIR=$ROOT/pkg
PATH=$ROOT/$NIM_VERSION/bin:$PATH nimble --nimbleDir:$ROOT/pkg \$@
END
    chmod +x nimble
    [ -d $ROOT/$WASI_VERSION ] || $SDKROOT/bin/wasi/clang -v

    echo install complete

else
    # run nim compilation flavour

    # TODO erase obj cache when changing arch

    truncate --size=0 $COMPILER_REPLAY

    if echo $0|grep -q 64$
    then
        BITS=64
    else
        # js/wasm/32
        BITS=32

    fi

    FLAVOUR=$(basename $0)

    echo "FLAVOUR=$FLAVOUR"

    NIM_CACHE=$ROOT/cache/$FLAVOUR


    # useless ?
    NIM_OPTS="-d:NIM_INTBITS=32"
    # --define:useRealtimeGC  ?


    export NIMBLE_DIR=$ROOT/pkg


    NIM_OPTS="--path:$NIMBLE_DIR --path:$ROOT/include --nimcache:$ROOT/cache/$FLAVOUR"
    NIM_OPTS="$NIM_OPTS --cc:clang --os:linux --colors:on"

    # gc arc / orc / none ?
    NIM_OPTS="$NIM_OPTS --exceptions:goto --usenimcache --opt:size --threads:off"
    NIM_OPTS="$NIM_OPTS --mm:orc --define:noSignalHandler"

    if [ -f dev ]
    then
        echo "DEBUG MODE"
        # --embedsrc:on
        NIM_OPTS="$NIM_OPTS -d:debug --checks:on --assertions:on"
    else
        # with  --checks:off int overflows are not detected
        NIM_OPTS="$NIM_OPTS -d:release --assertions:off"
    fi

    export PATH=$NIMROOT/bin:/bin:/usr/bin:/usr/local/bin

    # ./nimble --verbose --debug install https://github.com/beef331/wasm3
    for pkg in pylib
    do
        if find $NIMBLE_DIR/pkgs/ -maxdepth 1 -type d |grep -q /${pkg}-
        then
            continue
        fi
        nimble -y install $pkg
    done

    # python transpilation
    if echo $@|grep -q \.py$
    then

        if python3 -m black -l 132 $@ && PYTHONPATH=/data/git/pygbag python3 -m pygbag --piny $@
        then
            FILENIM=$(dirname $@)/$(basename $@ .py).pn
        else
            echo "bad file"
            exit 1
        fi
    else
        FILENIM=$@
    fi

    BINOUT=$ROOT
    EXE=out/app

    [ -f $BINOUT/$EXE ] && rm $BINOUT/$EXE

    if ${NIM_NOMAIN:-true}
    then
        MAIN="--noMain:on"
    else
        echo "
         *** Not adding reactor support ***
        "
        MAIN=""
    fi

    export NIM_NOMAIN


    case $FLAVOUR in

        nimwasi)
            # switch clang
            export PATH=$SDKROOT/bin/wasi:$PATH

            summary wasi via wasi-sdk
            [ -f out.wasm ] && rm out.wasm
            #  --cincludes:$ROOT/bin/wasi
            nim c -d:release $MAIN \
             $NIM_OPTS \
             --cc:clang --cpu:wasm32 --os:linux \
             -d:emscripten -d:wasi \
             -d:def_WASM_cpp -d:def_32_cpp  \
             --passC:"-m32" --passL:-m32 \
             --outdir:$BINOUT -o:$EXE $FILENIM


            if [ -f $EXE ]
            then
                echo "
        moving program $EXE to out.wasm and running via wasm3
    _______________________________________________________________

            "
                mv $EXE out.wasm
                ./runtimes/wasm3 out.wasm
            else
                echo Build error
            fi

        ;;

        nimweb)
            # switch clang
            export PATH=$SDKROOT/bin/wasi:$PATH

            summary wasi via wasi-sdk with web reactor
            [ -f out.wasm ] && rm out.wasm

            # tell clang to change startup to reactor
            export NIM_NOMAIN=true

            nim c -d:release $MAIN \
             $NIM_OPTS \
             --cc:clang --cpu:wasm32 --os:linux \
             -d:emscripten -d:wasi -d:reactor \
             -d:def_WASM_cpp -d:def_32_cpp  \
             --passC:"-m32" --passL:-m32 \
             --outdir:$BINOUT -o:$EXE $FILENIM


            if [ -f $EXE ]
            then
                echo "
        moving program $EXE to out.wasm and running via wasm3
    _______________________________________________________________

            "
                mv $EXE out.wasm
                ./runtimes/wasm3.reactor out.wasm
            else
                echo Build error
            fi

        ;;



        nimemsdk)
            # switch clang
            export PATH=${ROOT}/bin/emsdk:$PATH
            export EMSDK_QUIET=1
            summary "wasm via emscripten"
            nim c \
             $NIM_OPTS \
             --cpu:wasm32 -d:emscripten \
             -d:def_WASM_cpp -d:def_32_cpp  \
             --passC:-m32 --passL:-m32 \
            --outdir:$BINOUT -o:$EXE $FILENIM

            if [ -f $EXE ]
            then
                . /opt/python-wasm-sdk/wasm32-mvp-emscripten-shell.sh
                NODE=$(find $EMSDK|grep /bin/node$)
                $NODE $BINOUT/$EXE
            else
                echo build error
            fi
        ;;


        *)
            summary "native 32/64"

            if echo $0|grep -q 32$
            then
                ARCH="--cpu:wasm32 --passC:-m32 --passL:-m32"
            else
                ARCH=""
            fi
            echo "_____________________________________________________"
            nim r $NIM_OPTS $ARCH \
             --outdir:$BINOUT -o:$EXE \
             -d:def_NODYNLIB_cpp -d:def_${BITS}_cpp $FILENIM

        ;;
    esac
fi


