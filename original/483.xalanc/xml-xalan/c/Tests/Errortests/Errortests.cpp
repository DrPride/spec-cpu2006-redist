/*
 * Copyright 1999-2004 The Apache Software Foundation.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <xalanc/Include/PlatformDefinitions.hpp>



#include <cstdio>

#if defined(XALAN_CLASSIC_IOSTREAMS)
#include <iostream.h>
#include <strstream.h>
#else
#include <iostream>
#include <strstream>
#endif


XALAN_USING_STD(cerr)
XALAN_USING_STD(cout)
XALAN_USING_STD(endl)



// XERCES HEADERS...
#include <xercesc/util/PlatformUtils.hpp>



// XALAN HEADERS...
#include <xalanc/PlatformSupport/DOMStringHelper.hpp>



#include <xalanc/XalanSourceTree/FormatterToSourceTree.hpp>
#include <xalanc/XalanSourceTree/XalanSourceTreeDOMSupport.hpp>
#include <xalanc/XalanSourceTree/XalanSourceTreeParserLiaison.hpp>



#include <xalanc/XalanTransformer/XalanTransformer.hpp>



#include <Harness/XMLFileReporter.hpp>
#include <Harness/FileUtility.hpp>
#include <Harness/HarnessInit.hpp>



// This is here for memory leak testing. 
#if !defined(NDEBUG) && defined(_MSC_VER)
#include <crtdbg.h>
#endif

const char* const 	excludeStylesheets[] =
{
	0
};



XALAN_USING_XALAN(FileUtility)
XALAN_USING_XALAN(XalanDOMString)



void
setHelp(FileUtility&	h)
{
	h.args.getHelpStream() << endl
		 << "errortests dir [-sub -out]"
		 << endl
		 << endl
		 << "dir		(location of conformance directory)"
		 << endl
		 << "-sub dir	(specific directory)"
		 << endl
		 << "-out dir	(base directory for output)"
		 << endl;
}



inline bool
checkForExclusion(const XalanDOMString&		currentFile)
{
	for (int i = 0; excludeStylesheets[i] != 0; i++)
	{
		if (currentFile == XalanDOMString(excludeStylesheets[i]))
		{
			return true;
		}
	}

	return false;
}



int
runTests(
			int		argc,
			char*	argv[])
{
	XALAN_USING_XALAN(HarnessInit)

	HarnessInit		xmlPlatformUtils;

	FileUtility		h;

	// Set the program help string,  then get the command line parameters.
	//
	setHelp(h);

	bool	setGold = false;

	if (h.getParams(argc, argv, "ERR-RESULTS", setGold) == true)
	{
		XALAN_USING_XALAN(XalanTransformer)
		XALAN_USING_XALAN(XalanSourceTreeDOMSupport)
		XALAN_USING_XALAN(XalanSourceTreeParserLiaison)
		XALAN_USING_XALAN(XMLFileReporter)

		XalanTransformer				xalan;

		XalanSourceTreeDOMSupport		domSupport;
		XalanSourceTreeParserLiaison	parserLiaison(domSupport);

		domSupport.setParserLiaison(&parserLiaison);

		// Generate Unique Run id and processor info
		const XalanDOMString UniqRunid = h.generateUniqRunid();

		// Defined basic constants for file manipulation and open results file
		const XalanDOMString  resultFilePrefix("cpperr");
		const XalanDOMString  resultsFile(h.args.output + resultFilePrefix + UniqRunid + FileUtility::s_xmlSuffix);

		XMLFileReporter		logFile(resultsFile);
		logFile.logTestFileInit("Error Testing:");

		// Get the list of Directories that are below conf
		bool foundDir = false;		// Flag indicates directory found. Used in conjunction with -sub cmd-line arg.

		typedef FileUtility::FileNameVectorType		FileNameVectorType;

		const FileNameVectorType	dirs = h.getDirectoryNames(h.args.base);

		for(FileNameVectorType::size_type	j = 0; j < dirs.size(); ++j)
		{
			// If conformance directory structure does not exist, it needs to be created.
			const XalanDOMString  confSubdir = h.args.output + dirs[j];
			h.checkAndCreateDir(confSubdir);

				// Set up to get files from the associated error directories
				const XalanDOMString&	currentDir = dirs[j];

				// Run specific category of files from given directory
				if (h.args.sub.empty() == true || currentDir == h.args.sub)
				{
					// Check that output directory is there.
					const XalanDOMString  theOutputDir = h.args.output + currentDir;
					h.checkAndCreateDir(theOutputDir);

					
					// Indicate that directory was processed and get test files from the directory
					foundDir = true;
					logFile.logTestCaseInit(currentDir);

					const FileNameVectorType files = h.getTestFileNames(h.args.base, currentDir, false);

					for(FileNameVectorType::size_type i = 0; i < files.size(); i++)
					{
						XALAN_USING_XALAN(XSLTInputSource)
						XALAN_USING_XALAN(XSLTResultTarget)
						XALAN_USING_XALAN(XalanCompiledStylesheet)
						XALAN_USING_XALAN(XalanParsedSource)

						XMLFileReporter::Hashtable	attrs;

						const XalanDOMString currentFile(files[i]);
						h.data.testOrFile = currentFile;

						if (checkForExclusion(currentFile))
							continue;

						const XalanDOMString  theXSLFile= h.args.base + currentDir + FileUtility::s_pathSep + currentFile;
						const XalanDOMString  theXMLFile = h.generateFileName(theXSLFile,"xml");
						XalanDOMString  theGoldFile = h.args.gold + currentDir + FileUtility::s_pathSep + currentFile;
						theGoldFile = h.generateFileName(theGoldFile, "out");

						const XalanDOMString  outbase =  h.args.output + currentDir + FileUtility::s_pathSep + currentFile; 
						const XalanDOMString  theOutputFile = h.generateFileName(outbase, "out");

						const XSLTInputSource	xslInputSource(theXSLFile);
						const XSLTInputSource	xmlInputSource(theXMLFile);
						const XSLTInputSource	goldInputSource(theGoldFile);
						const XSLTResultTarget	resultFile(theOutputFile);

						// Parsing(compile) the XSL stylesheet and report the results..
						//
						const XalanCompiledStylesheet*	compiledSS = 0;
						try 
						{
							cout << endl << "PARSING STYLESHEET FOR: " << currentFile << endl;

							xalan.compileStylesheet(xslInputSource, compiledSS);
							if (compiledSS == 0 )
							{
								cout << "FAILED to parse stylesheet for " << currentFile << endl;
								cout << "Reason: " << xalan.getLastError() << endl;
								logFile.logErrorResult(currentFile, XalanDOMString(xalan.getLastError()));
								continue;
							}
						}
						catch(...)
						{
							cerr << "Exception caught!!!" << endl << endl;
						}

						// Parsing the input XML and report the results..
						//
						cout << "PARSING SOURCE XML FOR: " << currentFile << endl;
						const XalanParsedSource*	parsedSource = 0;
						xalan.parseSource(xmlInputSource, parsedSource);
						if (parsedSource == 0)
						{
							cout << "Failed to PARSE source document for " << currentFile << endl;
							continue;
						}

						// Perform One transform using parsed stylesheet and parsed xml source, report results...
						// 
						cout << "TRANSFORMING: " << currentFile << endl;

						const int	theResult = xalan.transform(*parsedSource, compiledSS, resultFile);

						if (theResult != 0)
						{
							cout << "FAILED to transform stylesheet for " << currentFile << endl;
							cout << "Reason: " << xalan.getLastError() << endl;
							logFile.logErrorResult(currentFile, XalanDOMString(xalan.getLastError()));
						}
						else
						{
							logFile.logCheckPass(currentFile);
						}

						parserLiaison.reset();
						xalan.destroyParsedSource(parsedSource);
						xalan.destroyStylesheet(compiledSS);
					}
				}

				logFile.logTestCaseClose("Done", "Pass");
			}


		// Check to see if -sub cmd-line directory was processed correctly.
		if (!foundDir)
		{
			cout << "Specified test directory: \"" << h.args.sub << "\" not found" << endl;
		}

		h.reportPassFail(logFile, UniqRunid);

		logFile.logTestFileClose("Conformance ", "Done");
		logFile.close();
	}

	return 0;
}



int
main(
			int		argc,
			char*	argv[])
{
#if !defined(NDEBUG) && defined(_MSC_VER)
	_CrtSetDbgFlag(_CrtSetDbgFlag(_CRTDBG_REPORT_FLAG) | _CRTDBG_LEAK_CHECK_DF);
	_CrtSetReportMode(_CRT_WARN, _CRTDBG_MODE_FILE);
	_CrtSetReportFile(_CRT_WARN, _CRTDBG_FILE_STDERR);
#endif

	int	theResult = 0;

	try
	{
		XALAN_USING_XERCES(XMLPlatformUtils)

		XALAN_USING_XALAN(XalanTransformer)

		// Call the static initializers for xerces and xalan, and create a transformer
		//
		XMLPlatformUtils::Initialize();

		XalanTransformer::initialize();

		theResult = runTests(argc, argv);

		XalanTransformer::terminate();

		XMLPlatformUtils::Terminate();

		XalanTransformer::ICUCleanUp();
	}
	catch(...)
	{
		cerr << "Initialization failed!" << endl << endl;

		theResult = -1;
	}

	return theResult;
}