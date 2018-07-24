/*
    Class to run shell commands and process exit value

    Author: Liza Dayoub

 */

class ShellCmd {

    // TODO: Real-time output capture
    public static String run(cmd) {
        def sout = new StringBuilder(), serr = new StringBuilder()
        def proc = (cmd).execute()
        proc.consumeProcessOutput(sout, serr)
        proc.waitFor()
        if (proc.exitValue() != 0) {
            if (serr) {
                throw new Exception(serr.toString())
            } else {
                throw new Exception("Exit value is not zero")
            }
        }
        return sout
    }

}