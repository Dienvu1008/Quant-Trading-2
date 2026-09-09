#ifndef __VP_EA_LOGGER_MQH__
#define __VP_EA_LOGGER_MQH__

enum ELogVerbosity
{
   LOG_SILENT  = 0,
   LOG_NORMAL  = 1,
   LOG_VERBOSE = 2
};

ELogVerbosity g_logVerbosity = LOG_NORMAL;

class CLogger
{
public:
   static void Info(const string msg)  { if (g_logVerbosity >= LOG_NORMAL)  Print("[INFO] ", msg); }
   static void Verbose(const string msg) { if (g_logVerbosity >= LOG_VERBOSE) Print("[VERBOSE] ", msg); }
   static void Error(const string msg) { Print("[ERROR] ", msg); }
};

#endif
