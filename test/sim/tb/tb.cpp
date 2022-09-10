#include <iostream>
#include <fstream>
#include <cstdint>
#include <string>
#include <stdio.h>

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

// Device-under-test model generated by CXXRTL:
#include "dut.cpp"
#include <backends/cxxrtl/cxxrtl_vcd.h>

// There must be a better way
#ifdef __x86_64__
#define I64_FMT "%ld"
#else
#define I64_FMT "%lld"
#endif

// -----------------------------------------------------------------------------

static const int MEM_SIZE = 16 * 1024 * 1024;

static const unsigned int IO_BASE = 0x80000000;
enum {
	IO_PRINT_CHAR  = 0x000,
	IO_PRINT_U32   = 0x004,
	IO_EXIT        = 0x008,
	IO_MTIME       = 0x100,
	IO_MTIMEH      = 0x104,
	IO_MTIMECMP    = 0x108,
	IO_MTIMECMPH   = 0x10c
};

struct mem_io_state {
	uint64_t mtime;
	uint64_t mtimecmp;

	bool exit_req;
	uint32_t exit_code;

	uint8_t *mem;

	mem_io_state() {
		mtime = 0;
		mtimecmp = 0;
		exit_req = false;
		exit_code = 0;
		mem = new uint8_t[MEM_SIZE];
		for (size_t i = 0; i < MEM_SIZE; ++i)
			mem[i] = 0;
	}

	// Where we're going we don't need a destructor B-)

	void step(cxxrtl_design::p_tb &tb) {
		// Default update logic for mtime, mtimecmp
		++mtime;
		// tb.p_timer__irq.set<bool>(mtime >= mtimecmp);
	}
};

uint32_t mem_access(cxxrtl_design::p_tb &tb, mem_io_state &memio, uint32_t addr, uint32_t wdata, uint8_t wstrobe) {
	addr &= ~0x3u;
	uint32_t rdata = 0;
	if (wstrobe != 0) {
		if (addr < MEM_SIZE) {
			for (int i = 0; i < 4; ++i) {
				if (wstrobe & (1u << i)) {
					memio.mem[addr + i] = wdata >> (8 * i) & 0xffu;
				}
			}
		}
		else if (addr == IO_BASE + IO_PRINT_CHAR) {
			putchar(wdata & 0xffu);
		}
		else if (addr == IO_BASE + IO_PRINT_U32) {
			printf("%08x\n", wdata);
		}
		else if (addr == IO_BASE + IO_EXIT) {
			if (!memio.exit_req) {
				memio.exit_req = true;
				memio.exit_code = wdata;
			}
		}
		else if (addr == IO_BASE + IO_MTIME) {
			memio.mtime = (memio.mtime & 0xffffffff00000000u) | wdata;
		}
		else if (addr == IO_BASE + IO_MTIMEH) {
			memio.mtime = (memio.mtime & 0x00000000ffffffffu) | ((uint64_t)wdata << 32);
		}
		else if (addr == IO_BASE + IO_MTIMECMP) {
			memio.mtimecmp = (memio.mtimecmp & 0xffffffff00000000u) | wdata;
		}
		else if (addr == IO_BASE + IO_MTIMECMPH) {
			memio.mtimecmp = (memio.mtimecmp & 0x00000000ffffffffu) | ((uint64_t)wdata << 32);
		}
	}
	else {
		if (addr < MEM_SIZE) {
			rdata =
				(uint32_t)memio.mem[addr] |
				memio.mem[addr + 1] << 8 |
				memio.mem[addr + 2] << 16 |
				memio.mem[addr + 3] << 24;
		}
		else if (addr == IO_BASE + IO_MTIME) {
			rdata = memio.mtime;
		}
		else if (addr == IO_BASE + IO_MTIMEH) {
			rdata = memio.mtime >> 32;
		}
		else if (addr == IO_BASE + IO_MTIMECMP) {
			rdata = memio.mtimecmp;
		}
		else if (addr == IO_BASE + IO_MTIMECMPH) {
			rdata = memio.mtimecmp >> 32;
		}
	}
	return rdata;
}

// -----------------------------------------------------------------------------

const char *help_str =
"Usage: tb [--bin x.bin] [--port n] [--vcd x.vcd] [--dump start end] \\\n"
"          [--cycles n] [--cpuret]\n"
"\n"
"    --bin x.bin      : Flat binary file loaded to address 0x0 in RAM\n"
"    --vcd x.vcd      : Path to dump waveforms to\n"
"    --dump start end : Print out memory contents from start to end (exclusive)\n"
"                       after execution finishes. Can be passed multiple times.\n"
"    --cycles n       : Maximum number of cycles to run before exiting.\n"
"                       Default is 0 (no maximum).\n"
"    --cpuret         : Testbench's return code is the return code written to\n"
"                       IO_EXIT by the CPU, or -1 if timed out.\n"
;

void exit_help(std::string errtext = "") {
	std::cerr << errtext << help_str;
	exit(-1);
}

static const int TCP_BUF_SIZE = 256;

int main(int argc, char **argv) {

	bool load_bin = false;
	std::string bin_path;
	bool dump_waves = false;
	std::string waves_path;
	std::vector<std::pair<uint32_t, uint32_t>> dump_ranges;
	int64_t max_cycles = 0;
	bool propagate_return_code = false;

	for (int i = 1; i < argc; ++i) {
		std::string s(argv[i]);
		if (s.rfind("--", 0) != 0) {
			std::cerr << "Unexpected positional argument " << s << "\n";
			exit_help("");
		}
		else if (s == "--bin") {
			if (argc - i < 2)
				exit_help("Option --bin requires an argument\n");
			load_bin = true;
			bin_path = argv[i + 1];
			i += 1;
		}
		else if (s == "--vcd") {
			if (argc - i < 2)
				exit_help("Option --vcd requires an argument\n");
			dump_waves = true;
			waves_path = argv[i + 1];
			i += 1;
		}
		else if (s == "--dump") {
			if (argc - i < 3)
				exit_help("Option --dump requires 2 arguments\n");
			dump_ranges.push_back(std::pair<uint32_t, uint32_t>(
				std::stoul(argv[i + 1], 0, 0),
				std::stoul(argv[i + 2], 0, 0)
			));;
			i += 2;
		}
		else if (s == "--cycles") {
			if (argc - i < 2)
				exit_help("Option --cycles requires an argument\n");
			max_cycles = std::stol(argv[i + 1], 0, 0);
			i += 1;
		}
		else if (s == "--cpuret") {
			propagate_return_code = true;
		}
		else {
			std::cerr << "Unrecognised argument " << s << "\n";
			exit_help("");
		}
	}
	if (!load_bin)
		exit_help("--bin must be specified.\n");

	mem_io_state memio;

	if (load_bin) {
		std::ifstream fd(bin_path, std::ios::binary | std::ios::ate);
		if (!fd){
			std::cerr << "Failed to open \"" << bin_path << "\"\n";
			return -1;
		}
		std::streamsize bin_size = fd.tellg();
		if (bin_size > MEM_SIZE) {
			std::cerr << "Binary file (" << bin_size << " bytes) is larger than memory (" << MEM_SIZE << " bytes)\n";
			return -1;
		}
		fd.seekg(0, std::ios::beg);
		fd.read((char*)memio.mem, bin_size);
	}

	cxxrtl_design::p_tb top;

	std::ofstream waves_fd;
	cxxrtl::vcd_writer vcd;
	if (dump_waves) {
		waves_fd.open(waves_path);
		cxxrtl::debug_items all_debug_items;
		top.debug_info(all_debug_items);
		vcd.timescale(1, "us");
		vcd.add(all_debug_items);
	}

	uint32_t bus_rdata_next;

	top.p_mem__stall.set<bool>(false);

	// Reset + initial clock pulse

	top.step();
	top.p_clk.set<bool>(true);
	top.step();
	top.p_clk.set<bool>(false);
	top.p_rst__n.set<bool>(true);
	top.step();
	top.step(); // workaround for github.com/YosysHQ/yosys/issues/2780

	bool timed_out = false;
	for (int64_t cycle = 0; cycle < max_cycles || max_cycles == 0; ++cycle) {
		top.p_clk.set<bool>(false);
		top.step();
		if (dump_waves)
			vcd.sample(cycle * 2);
		top.p_clk.set<bool>(true);
		top.step();
		top.step(); // workaround for github.com/YosysHQ/yosys/issues/2780

		memio.step(top);

		top.p_mem__rdata.set<uint32_t>(bus_rdata_next);

		bool ren = top.p_mem__ren.get<bool>();
		uint8_t wen = top.p_mem__wen.get<uint8_t>();
		uint32_t addr = top.p_mem__addr.get<uint32_t>();
		uint32_t wdata = top.p_mem__wdata.get<uint32_t>();

		if (ren || wen) {
			bus_rdata_next = mem_access(top, memio, addr, wdata, wen);
		}
		else {
			bus_rdata_next = 0;
		}

		if (dump_waves) {
			// The extra step() is just here to get the bus responses to line up nicely
			// in the VCD (hopefully is a quick update)
			top.step();
			vcd.sample(cycle * 2 + 1);
			waves_fd << vcd.buffer;
			vcd.buffer.clear();
		}

		if (memio.exit_req) {
			printf("CPU requested halt. Exit code %d\n", memio.exit_code);
			printf("Ran for " I64_FMT " cycles\n", cycle + 1);
			break;
		}
		if (cycle + 1 == max_cycles) {
			printf("Max cycles reached\n");
			timed_out = true;
		}
	}

	for (auto r : dump_ranges) {
		printf("Dumping memory from %08x to %08x:\n", r.first, r.second);
		for (int i = 0; i < r.second - r.first; ++i)
			printf("%02x%c", memio.mem[r.first + i], i % 16 == 15 ? '\n' : ' ');
		printf("\n");
	}

	if (propagate_return_code && timed_out) {
		return -1;
	}
	else if (propagate_return_code && memio.exit_req) {
		return memio.exit_code;
	}
	else {
		return 0;
	}
}
