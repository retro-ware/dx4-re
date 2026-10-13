// Headless: create functions at TP7 procedure starts and dump decompiled C + disassembly.
// args: <out_dir> <starts_file>  (starts file: one "SSSS:OOOO" per line)
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import java.io.*;
import java.nio.file.*;

public class DumpAll extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] a = getScriptArgs();
        File out = new File(a[0]); out.mkdirs();
        AddressFactory af = currentProgram.getAddressFactory();
        for (String line : Files.readAllLines(Paths.get(a[1]))) {
            line = line.trim(); if (line.isEmpty()) continue;
            Address ad = af.getAddress(line);
            new DisassembleCommand(ad, null, true).applyTo(currentProgram, monitor);
            if (getFunctionAt(ad) == null) createFunction(ad, "p_" + line.replace(':', '_'));
        }
        analyzeChanges(currentProgram);
        DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            DecompileResults r = di.decompileFunction(f, 60, monitor);
            String c = r.decompileCompleted() ? r.getDecompiledFunction().getC() : "// failed\n";
            try (PrintWriter w = new PrintWriter(new File(out, f.getName() + ".c"))) { w.print(c); }
        }
    }
}
