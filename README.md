# Example VHDL project for a Digilent Anvyl Spartan-6 board using open tooling (where possible)

This is an example development workflow for the [Digilent Anvyl](https://digilent.com/reference/programmable-logic/anvyl/start) 2012-era FPGA development board, which features a Xilinx Spartan-6 FPGA.

It uses the open-source [Yosys synthesizer](https://github.com/YosysHQ/yosys) (and its [GHDL plugin for VHDL input](https://github.com/ghdl/ghdl-yosys-plugin)) to read your VHDL files and turn them into netlists targeting a Spartan-6 FPGA.

Then it uses [a Dockerized version](https://github.com/90degs2infty/ise-docker/tree/80f46139b852f98ca67c31d5f3b4aaebda98851c) of [Xilinx's proprietary, discontinued ISE toolchain](https://www.xilinx.com/downloadNav/vivado-design-tools/archive-ise.html) to do placement and routing and create a .bit bitstream file from the netlist. 

Finally, you can use the open-source [OpenOCD](https://openocd.org/) to upload the resulting .bit file to the board.

## Usage

1. Download the Linux ISE zip-xz-balls (probably [directly from the Xilinx website](https://www.xilinx.com/downloadNav/vivado-design-tools/archive-ise.html), after making an account there). You want:

```shell
$ cat Xilinx_ISE_DS_14.7_1015_1.md5sums 
ff0f8a08aba2b7110fa730c6b15067d6 Xilinx_ISE_DS_14.7_1015_1-1.tar
c0962036464ff6b772b20c032b2f954b Xilinx_ISE_DS_14.7_1015_1-2.zip.xz
e6146a7eac7c026b4b507fdfb7549e4e Xilinx_ISE_DS_14.7_1015_1-3.zip.xz
90943813f27a083e8929f3e742416417 Xilinx_ISE_DS_14.7_1015_1-4.zip.xz
$ cat Xilinx_ISE_DS_14.7_1015_1.sha256sums 
cb3f968db695d808fe07a38ed04e695c881a62b8c177dfe3f608c9b8b65132e9  Xilinx_ISE_DS_14.7_1015_1-1.tar
6f838167149c9488e42aa99ba79c10772397a4b47c8aac942ef5b11019fbd55a  Xilinx_ISE_DS_14.7_1015_1-2.zip.xz
a8688eda89a4e5bcf048dcbee4deca2b00cd7fefbdf9de5b56e79876fc855ef4  Xilinx_ISE_DS_14.7_1015_1-3.zip.xz
229449dfc318cc56b2aaa07577e5979e680aa63a1d0825ecde612e34a9ad8c26  Xilinx_ISE_DS_14.7_1015_1-4.zip.xz
```

2. Build your [ISE Docker image](https://github.com/90degs2infty/ise-docker/tree/80f46139b852f98ca67c31d5f3b4aaebda98851c) following that repo's instructions. It seems nobody is distributing containers with ISE pre-installed. Tag the image as `xilinx-ise`.

2. Get a license file for ISE and put it at `~/.Xilinx/Xilinx.lic`. They look sort of like [what David\_E shows here](https://support.xilinx.com/s/question/0D54U00007uMOmMSAW/new-license-file-is-licensing-isewebpack-ise-tool-is-looking-for-webpack-how-to-resolve?language=zh_CN). You can get these [directly from Xilinx (now AMD)](https://xilinx.com/getlicense) after registering an account; you want the free "Webpack" version.

It's not clear what license exactly they are licensing anything under: when I got mine it just asked me to agree to the AMD website's terms of service. The workflow here runs ISE with no network access, so it's unlikely to stop working because e.g. you are running it from a bunch of IP addresses in CI. You yourself are responsible for complying with any license agreements you agree to about how and where you run ISE.

3. Edit `main.vhd` and write your VHDL code. The default design is based on the `01.Anvyl_SW_LED_Demo` example from the Anvyl manual, modified to use slightly more standard VHDL. If you use more pins than the example, you will also need to edit the "user constraints file" `user.ucf` and add in more lines from [the official Anvyl UCF](https://digilent.com/reference/_media/reference/programmable-logic/anvyl/anvyl-master_ucf.zip) to connect pin names in your design to the pads on the FPGA chip that are actually wired up to the peripherals on the board.

4. Run `./build.sh`, which will invoke Yosys, and then ISE, and (after about a minute) spit out a `.bit` file as `main.bit`. If you want to customize the names of files or the set of files in the project, edit that script. (If Yosys is acting up, you can edit the script to set `VHDL_FRONTEND="ise"` instead, to make it do synthesis with ISE instead.)

5. Use the open-source [OpenOCD](https://openocd.org/) (as long as it has [this patch](https://review.openocd.org/c/openocd/+/8467)) to upload the .bit file to the Anvyl board with:

```shell
openocd -f board/digilent_anvyl.cfg -c "init; virtex2 refresh xc6s.pld; pld load xc6s.pld main.bit ; exit"
```

If you need to install that OpenOCD from source:
local
```shell
git clone https://github.com/interfect/openocd.git
cd openocd
git fetch
git checkout digilent-anvyl
./bootstrap
./configure --prefix="${HOME}/.local"
make -j8
make install
export PATH="${HOME}/.local/bin:${PATH}"
```

Or if you are stuck with OpenOCD 0.11 from the Ubuntu repos:
```shell
cat >anvyl.cfg <<'EOF'
adapter driver ftdi
# OpenOCD 0.11 needs "ftdi_xxx" commands
# OpenOCD 0.12 can take "ftdi xxx" commands
ftdi_vid_pid 0x0403 0x6010
ftdi_device_desc "Digilent USB Device"
ftdi_channel 0
ftdi_layout_init 0x0088 0x008b
reset_config none
EOF
# cpld/xilinx-xc6s.cfg is found on OpenOCD's search path
openocd -f ./anvyl.cfg -f cpld/xilinx-xc6s.cfg -c "adapter speed 1000; transport select jtag; init; xc6s_program xc6s.tap; pld load 0 main.bit; exit"
```

6. Enjoy your pet Cylon:

![LEDs strobing across at different speeds as switches are flicked on the Digilent Anvyl board](doc/cylon.gif)

7. For a one-command development loop (edit VHDL, mash up arrow and enter, wait, flick switch on board, cry, repeat):

```shell
./build.sh && openocd -f board/digilent_anvyl.cfg -c "init; virtex2 refresh xc6s.pld; pld load xc6s.pld main.bit ; exit"
```
