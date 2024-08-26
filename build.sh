#!/usr/bin/env bash
set -ex

# How dhould we run the ISE tools?
# If "docker", runs ISE via a container.
# Otherwise, expects to find them on the PATH.
# Can be "docker" or anything else
ISE_MODE="docker"

# What Docker image should we use for ISE?
# Build <https://github.com/90degs2infty/ise-docker/tree/feature_refactor> at about 80f46139b852f98ca67c31d5f3b4aaebda98851c and tag it.
ISE_CONTAINER="xilinx-ise"

# What license file should we provide to the container?
# You need a file like the one in <https://support.xilinx.com/s/question/0D54U00007uMOmMSAW/new-license-file-is-licensing-isewebpack-ise-tool-is-looking-for-webpack-how-to-resolve?language=zh_CN>
ISE_LICENSE_PATH="${HOME}/.Xilinx/Xilinx.lic"

# What directory should we mount into the ISE container?
PROJECT_ROOT="$(pwd)"

function run_ise() {
    # Run a Xilinx ISE command
    
    if [[ "${ISE_MODE}" == "docker" ]] ; then
    
        if which podman >/dev/null
        then
            local RUNNER=podman
        elif which docker >/dev/null
        then
            local RUNNER=docker
        else
            echo "neither 'podman' nor 'docker' is available to run the container"
            exit 1
        fi
        
        ${RUNNER} run \
            -it \
            --rm \
            --net=none \
            --user $(id -u) \
            -e HOME=/home/ise \
            -v "${ISE_LICENSE_PATH}":/home/ise/.Xilinx/Xilinx.lic:ro \
            -v "${PROJECT_ROOT}":/workspace \
            -w /workspace \
            xilinx-ise \
            "${@}"
    else
        # Just run the command here.
        "${@}"
    fi
}

# The actual build

# Input source files
VHDL_FILES=(main.vhd)

# Input "user constraints file" defining the pinout you want to use on the FPGA pins.
UCF_FILE="user.ucf"

# Top-level VHDL component to synthesize
VHDL_UNIT="main"
# Xilinx FPGA family to make Yosys synthesize for. See <https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd/synth_xilinx.html>
# Use xc6s for Spartan 6
YOSYS_XILINX_FAMILY="xc6s"
# ISE part name for the FPGA to place and route on.
# THe part on the Digilent Anvyl is the xc6slx45-3-csg484
ISE_PART="xc6slx45-3-csg484"

# Where the netlist output goes
EDIF_FILE="main.edif"
# Extra flags to GHDL Yosys plugin for controling VHDL interpretation.
# If your VHDL uses the pseudostandard Synopsys imports to do math directly on
# logic-typoe values, like "STD_LOGIC_ARITH", you need -fsynopsys here.
GHDL_FLAGS=(-fsynopsys)

# Use the GHDL Yosys plugin to synthesize VHDL
# See <https://github.com/ghdl/ghdl-yosys-plugin?tab=readme-ov-file#containers>
# Use a bunch of magic clock-related commands from <https://github.com/9ary/yosys-spartan6-example/blob/618328a594641ed27a6648118c20a5e6be1da99c/synthesize.sh>
docker run --rm -t \
  -v "${PROJECT_ROOT}":/workspace \
  -w /workspace \
  hdlc/ghdl:yosys \
  yosys -m ghdl -p "ghdl -fsynopsys ${VHDL_FILES[@]} -e ${VHDL_UNIT}; synth_xilinx -family ${YOSYS_XILINX_FAMILY} -top ${VHDL_UNIT} -retime; select -set clocks */t:FDRE %x:+FDRE[C] */t:FDRE %d; iopadmap -inpad BUFGP O:I @clocks; iopadmap -outpad OBUF I:O -inpad IBUF O:I @clocks %n; write_edif ${EDIF_FILE}"

# Now make all the ISE files

# -mt option supports "on", "off", or exactly 1 to 4 threads
# Modern systems probably have 4 or more threads.
# TODO: Xilinx may refuse to actually run multiple threads for the Place and route step.
ISE_THREADS="4"

# Make the NGD (ISE's version of a netlist)
NGD_FILE="${EDIF_FILE%.edif}.ngd"
run_ise ngdbuild -uc "${UCF_FILE}" -p "${ISE_PART}" "${EDIF_FILE}" "${NGD_FILE}"

# Make the _map NCD file (technology mapping???)
MAP_NCD_FILE="${NGD_FILE%.ngd}_map.ncd"
# Also makes a PCF file for timing
MAP_PCF_FILE="${MAP_NCD_FILE%.ncd}.pcf"
# TODO: What do these other options do? See <https://github.com/9ary/yosys-spartan6-example/blob/618328a594641ed27a6648118c20a5e6be1da99c/synthesize.sh#L35>
run_ise map -p "${ISE_PART}" -w -mt "${ISE_THREADS}" -o "${MAP_NCD_FILE}" "${NGD_FILE}"

# Make the normal NCD file (place and route)
NCD_FILE="${MAP_NCD_FILE%_map.ncd}.ncd"

run_ise par -w -mt "${ISE_THREADS}" "${MAP_NCD_FILE}" "${NCD_FILE}"

# Compute a timing report
TWR_FILE="${NCD_FILE%.ncd}.twt"
run_ise trce -v -n -fastpaths "${NCD_FILE}" -o "${TWR_FILE}" "${MAP_PCF_FILE}"

# Also make the bitstream file
# TODO: We don't get to specify the name actually?
BIT_FILE="${NCD_FILE%.ncd}.bit"
run_ise bitgen -w -g Binary:Yes -g UnusedPin:PullNone "${NCD_FILE}"


