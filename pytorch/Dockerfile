FROM fedora

RUN dnf install -y \
        python3.7 \
        python3-virtualenv.noarch \
        git \
        blas-devel \
        gcc-c++ \
        cmake \
        python3-devel \
        protobuf-compiler \
        protobuf-devel \
        llvm7.0-devel \
        redhat-rpm-config \
        libGL

RUN cd && \
    virtualenv -p 3.7 venv && \
    source venv/bin/activate && \
    python -m pip install --upgrade pip && \
    pip install \
        torch \
        torchtext \
        torchvision && \
    cd && \
    git clone https://github.com/numba/llvmlite.git && \
        cd llvmlite && \
        git checkout v0.31.0 && \
        export CPU_COUNT=$(grep -cE '^processor[[:space:]:]'  /proc/cpuinfo) && \
        export LLVM_CONFIG=/usr/lib64/llvm7.0/bin/llvm-config && \
        python setup.py build && \
        python runtests.py && \
        python setup.py install && \
    cd && \
    git clone git://github.com/numba/numba.git && \
        cd numba && \
        git checkout 0.48.0 && \
        python setup.py install && \
    cd  && \
    git clone https://github.com/chrisstaite/lameenc && \
        cd lameenc && \
        git checkout v1.2.2 && mkdir build && \
        sed -i 's|3.7|3.7.10|g; s|find_package.*|find_package(PythonInterp "${Version}" EXACT QUIET)|g' CMakeLists.txt && \
        cd build && \
        cmake .. && \
        make && \
        pip install lameenc*.whl && \
    cd && \
    git clone --recurse-submodules https://github.com/dmlc/dgl.git && \
        cd dgl && \
        git submodule update --init --recursive && \
        git checkout v0.5.0 && \
        git clean -fd && \
        mkdir build && \
        cd build && \
        cmake .. && \
        make -j4 && \
        cd ../python && \
        python setup.py install && \
    cd && \
    git clone https://github.com/pytorch/benchmark.git && \
        cd benchmark/ && \
        sed -i '/^numba/d' torchbenchmark/models/tacotron2/requirements.txt && \
        python install.py -v && \
    echo -e '[pytest]\nconsole_output_style=progress\nlog_cli=true' > pytest.ini && \
    pip uninstall -y numpy && \
    pip install numpy

COPY run.sh /root/benchmark/

ENTRYPOINT [ "/root/benchmark/run.sh" ]
