module app;

import tested;

void main()
{
	version (unittest) {} else {
		import std.stdio;
		writeln(`This application does nothing. Run with "dub --build=unittest"`);
	}
}

shared static this()
{
	version (unittest) {
		// disable built-in unit test runner
		import gridworldmdptest;
        import gridworldirltest;
        import discretefunctionstest;
        import randommdptest;
        import trajectorytest;
        import occlusiontest;
                        
		import core.runtime;
		Runtime.moduleUnitTester = () => true;
//		runUnitTests!(gridworld)(new JsonTestResultWriter("results.json"));

        bool allSuccessful = true;
        
		allSuccessful &= runUnitTests!(occlusiontest)(new ConsoleTestResultWriter);
		allSuccessful &= runUnitTests!(trajectorytest)(new ConsoleTestResultWriter);
		allSuccessful &= runUnitTests!(randommdptest)(new ConsoleTestResultWriter);
		allSuccessful &= runUnitTests!(gridworldmdptest)(new ConsoleTestResultWriter);
		allSuccessful &= runUnitTests!(gridworldirltest)(new ConsoleTestResultWriter);
		allSuccessful &= runUnitTests!(discretefunctionstest)(new ConsoleTestResultWriter);

        assert(allSuccessful, "Unit tests failed.");
        
	}
}
