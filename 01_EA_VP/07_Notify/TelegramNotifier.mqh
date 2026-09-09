#ifndef __VP_EA_TELEGRAM_NOTIFIER_MQH__
#define __VP_EA_TELEGRAM_NOTIFIER_MQH__

//+------------------------------------------------------------------+
//| Telegram Notifier — sends trade events (open / modify / close)   |
//| to a Telegram chat via the Bot API using WebRequest.             |
//|                                                                  |
//| SETUP REQUIRED (one-time, in MetaTrader 5):                      |
//|   Tools > Options > Expert Advisors > "Allow WebRequest for      |
//|   listed URL" and add:  https://api.telegram.org                 |
//|                                                                  |
//| To get botToken: talk to @BotFather, create a bot, copy token.  |
//| To get chatId: message the bot, then open                       |
//|   https://api.telegram.org/bot<token>/getUpdates and read        |
//|   result[].message.chat.id                                       |
//|                                                                  |
//| Notes:                                                           |
//|  - WebRequest is SYNCHRONOUS and does not work in the Strategy   |
//|    Tester. It only runs on live/demo charts. The notifier is a   |
//|    no-op when enabled=false or in tester mode.                   |
//+------------------------------------------------------------------+
class CVPTelegramNotifier
{
private:
   bool   m_enabled;
   string m_botToken;
   string m_chatId;
   string m_prefix;      // optional label (e.g. account/EA name) shown in each msg
   int    m_timeoutMs;

   // URL-encode a string for application/x-www-form-urlencoded bodies.
   string UrlEncode(const string text)
   {
      string result = "";
      uchar bytes[];
      int n = StringToCharArray(text, bytes, 0, -1, CP_UTF8);
      // StringToCharArray appends a trailing 0 terminator — skip it.
      for (int i = 0; i < n - 1; i++)
      {
         uchar c = bytes[i];
         bool unreserved = (c >= '0' && c <= '9') ||
                           (c >= 'A' && c <= 'Z') ||
                           (c >= 'a' && c <= 'z') ||
                           c == '-' || c == '_' || c == '.' || c == '~';
         if (unreserved)
            result += CharToString(c);
         else
            result += StringFormat("%%%02X", c);
      }
      return result;
   }

   // Format ulong ticket safely — StringFormat %I64u is unreliable across versions.
   string TicketStr(ulong ticket) { return IntegerToString((long)ticket); }

   bool Send(const string message)
   {
      if (!m_enabled) return false;
      if (m_botToken == "" || m_chatId == "") return false;
      // WebRequest is unavailable in the Strategy Tester.
      if ((bool)MQLInfoInteger(MQL_TESTER)) return false;

      string url = "https://api.telegram.org/bot" + m_botToken + "/sendMessage";
      string body = "chat_id=" + m_chatId +
                    "&parse_mode=HTML" +
                    "&disable_web_page_preview=true" +
                    "&text=" + UrlEncode(message);

      char post[];
      int len = StringToCharArray(body, post, 0, -1, CP_UTF8);
      if (len > 0) len--;              // drop trailing null terminator
      ArrayResize(post, len);

      char result[];
      string resultHeaders;
      string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

      ResetLastError();
      int code = WebRequest("POST", url, headers, m_timeoutMs, post, result, resultHeaders);
      if (code == -1)
      {
         int err = GetLastError();
         PrintFormat("[TELEGRAM] WebRequest failed err=%d. Did you whitelist "
                     "https://api.telegram.org in Tools > Options > Expert Advisors?", err);
         return false;
      }
      if (code != 200)
      {
         string resp = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         PrintFormat("[TELEGRAM] HTTP %d: %s", code, resp);
         return false;
      }
      PrintFormat("[TELEGRAM] Sent OK (HTTP 200) len=%d", len);
      return true;
   }

   string DirStr(bool isBuy) { return isBuy ? "BUY" : "SELL"; }

   // Status icons using plain ASCII so the .mqh file stays ANSI-safe.
   // Telegram renders HTML, so we use bold text instead of emoji for reliability.
   string TagOpen()  { return "[OPEN]";   }
   string TagModify(){ return "[MODIFY]"; }
   string TagClose(double pnl){ return (pnl >= 0) ? "[WIN]" : "[LOSS]"; }

public:
   CVPTelegramNotifier(void)
   {
      m_enabled = false; m_botToken = ""; m_chatId = "";
      m_prefix = ""; m_timeoutMs = 5000;
   }

   void Bootstrap(bool enabled, const string botToken, const string chatId,
                  const string prefix = "")
   {
      m_enabled  = enabled;
      m_botToken = botToken;
      m_chatId   = chatId;
      m_prefix   = prefix;

      if (!enabled)
      {
         Print("[TELEGRAM] Notifications disabled.");
         return;
      }
      if (botToken == "" || chatId == "")
      {
         Print("[TELEGRAM] WARNING: enabled=true but botToken or chatId is empty — notifications will not send.");
         m_enabled = false;   // force off to avoid silent fails
         return;
      }
      PrintFormat("[TELEGRAM] Ready. chatId=%s prefix='%s'", chatId, prefix);
   }

   bool IsEnabled(void) const { return m_enabled; }

   // ─── Event: trade opened ─────────────────────────────────────────
   void NotifyOpen(const string symbol, ulong ticket, bool isBuy, double lots,
                   const string setup, double entry, double sl, double tp, double rr)
   {
      if (!m_enabled) return;
      string pfx = (m_prefix == "" ? "" : "<b>" + m_prefix + "</b> ");
      string msg = pfx + TagOpen() + " <b>" + symbol + " " + DirStr(isBuy) + "</b>\n" +
                   "Ticket: <code>" + TicketStr(ticket) + "</code>\n" +
                   "Setup: " + setup + " | Lots: " + DoubleToString(lots, 2) + "\n" +
                   "Entry: " + DoubleToString(entry, 5) + "\n" +
                   "SL: " + DoubleToString(sl, 5) + "\n" +
                   "TP: " + DoubleToString(tp, 5) + "\n" +
                   "RR: " + DoubleToString(rr, 2);
      Send(msg);
   }

   // ─── Event: stop-loss modified ───────────────────────────────────
   void NotifyModify(const string symbol, ulong ticket, double oldSL, double newSL,
                     double tp)
   {
      if (!m_enabled) return;
      string pfx = (m_prefix == "" ? "" : "<b>" + m_prefix + "</b> ");
      string msg = pfx + TagModify() + " <b>" + symbol + "</b>\n" +
                   "Ticket: <code>" + TicketStr(ticket) + "</code>\n" +
                   "SL: " + DoubleToString(oldSL, 5) + " -> " + DoubleToString(newSL, 5) + "\n" +
                   "TP: " + DoubleToString(tp, 5);
      Send(msg);
   }

   // ─── Event: trade closed ─────────────────────────────────────────
   void NotifyClose(const string symbol, ulong ticket, const string reason,
                    double exitPrice, double profitUSD, double profitPips)
   {
      if (!m_enabled) return;
      string pfx = (m_prefix == "" ? "" : "<b>" + m_prefix + "</b> ");
      string pnlSign = (profitUSD >= 0) ? "+" : "";
      string msg = pfx + TagClose(profitUSD) + " <b>" + symbol + "</b>\n" +
                   "Ticket: <code>" + TicketStr(ticket) + "</code>\n" +
                   "Reason: " + reason + "\n" +
                   "Exit: " + DoubleToString(exitPrice, 5) + "\n" +
                   "P/L: <b>" + pnlSign + DoubleToString(profitUSD, 2) + " USD</b>" +
                   " (" + pnlSign + DoubleToString(profitPips, 1) + " pips)";
      Send(msg);
   }

   // ─── Generic text (for custom alerts) ────────────────────────────
   void NotifyText(const string text)
   {
      if (!m_enabled) return;
      string pfx = (m_prefix == "" ? "" : "<b>" + m_prefix + "</b> ");
      Send(pfx + text);
   }
};

#endif
