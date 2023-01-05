#!/bin/bash
ROOT=$(pwd)
SDKROOT=$(realpath $(dirname $0))
. $SDKROOT/config

NIMROOT=$ROOT/$NIM_VERSION

reset
echo CC_REPLAY=$CC_REPLAY
export CC_REPLAY

if echo $0|grep -q piny.sh$
then
    echo installing ...
    mkdir -p $ROOT/bin $ROOT/state $ROOT/pkg

    # cannot ln on cross dev
    cp -rf $SDKROOT/* ./

    rm nimjs nimwasi nim32 nim64

    for lnk in nimjs nimwasi nim32 nim64
    do
        if [ -f $ROOT/$lnk ]
        then
            continue
        else
            ln piny.sh $ROOT/$lnk
            chmod +x $ROOT/$lnk
        fi
    done


    if [ -d $NIM_VERSION ]
    then
        echo -n
    else
        wget -c $NIM_URL
        tar xf ${NIM_VERSION}-linux_*.tar.xz
    fi

    [ -d $ROOT/$WASI_VERSION ] || $SDKROOT/bin/wasi/clang -v

    echo install complete

else
    # run nim compilation flavour

    # TODO erase obj cache when changing arch

    truncate --size=0 $CC_REPLAY

    if echo $0|grep -q 64$
    then
        BITS=64
    else
        # js/wasm/32
        BITS=32

    fi


    export PATH=$NIMROOT/bin:/bin:/usr/bin:/usr/local/bin
    export NIMBLE_DIR=$ROOT/pkg

    for pkg in pylib
    do
        if find $NIMBLE_DIR/pkgs/ -maxdepth 1 -type d |grep -q /${pkg}-
        then
            continue
        fi
        nimble -y install $pkg
    done

    case $0 in
        */nimwasi)
            echo wasi via wasi-sdk
            export PATH=$SDKROOT/bin/wasi:$PATH
            echo "_________________ $NIMROOT $BITS ________________"
            echo $PATH
            echo python=$(python -V 2>&1)
            echo python3=$(python3 -V 2>&1)
            which clang
            which nim
            which nimble
            echo "____________________________________________________"
            [ -f out.wasm ] && rm out.wasm
            # -d:release
            nim r --gc:none --noMain:on --cc:clang --passC:"-m32 -I$ROOT/bin/wasi" --passL:-m32  \
             --path:$NIMBLE_DIR -d:def_WASM_cpp -d:NIM_INTBITS=32 -d:def_32_cpp -d:emscripten -d:wasi --threads:off "$@"
            exe=$(tail -n 1 $CC_REPLAY|cut  -d' ' -f8)
            if echo $exe|grep -q nim
            then
                echo "
        Running program $exe via wasm3 instead

    _______________________________________________________________

            "
                ./wasm3 $exe
                mv $exe out.wasm
            else
                echo Build error
            fi

        ;;

        */nimwasm)
            rm -rf /Users/user/.cache/nim/pinytest_d/pinytest_*
            echo wasm via emscripten
            export PATH=${ROOT}/bin-wasm:$PATH
            export EMSDK_QUIET=1
            echo "____________________________________________________"
            python -V
            which clang
            echo "____________________________________________________"

            $NIMBIN/nim r \
             --gc:none --cc:clang --passC:-m32 --passL:-m32 \
             --path:$NIMBLE_DIR -d:def_WASM_cpp -d:def_32_cpp -d:emscripten --threads:off "$@" 2>&1 | tee -a clog
            . /opt/python-wasm-sdk/wasm32-mvp-emscripten-shell.sh
            node $( tail -n 1 clog|cut -d\' -f2 )
        ;;

        *)
            rm -rf /Users/user/.cache/nim/pinytest_d/pinytest_*
            echo "native or js"
            echo "_________________ $NIMROOT $BITS ________________"
            echo $PATH
            echo python=$(python -V 2>&1)
            echo python3=$(python3 -V 2>&1)
            which clang
            which nim
            which nimble
            echo "____________________________________________________"

            if echo $0|grep -q 32$
            then
                ARCH="--cc:clang --passC:-m32 --passL:-m32"
            else
                ARCH="--cc:clang"
            fi
            echo "_____________________________________________________"
            nim r $ARCH --path:$NIMBLE_DIR -d:def_NODYNLIB_cpp -d:def_${BITS}_cpp --threads:off "$@"

        ;;
    esac
fi


