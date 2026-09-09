#ifndef __VP_EA_ECONOMICCALENDAR_MQH__
#define __VP_EA_ECONOMICCALENDAR_MQH__

#include "..\Config\GlobalParameters.mqh"

//+------------------------------------------------------------------+
//| Economic Calendar — News Filter for VP EA                        |
//| Uses MQL5 built-in CalendarValueHistory to detect upcoming       |
//| high-impact events. Blocks entries within configurable window.   |
//+------------------------------------------------------------------+

class CVPEconomicCalendar : public CVPModuleBase
{
private:
   int m_blockMinsBefore;
   int m_blockMinsAfter;
   datetime m_lastCheck;
   bool m_nearNews;
   int  m_minutesToNext;
   string m_nextEventName;

public:
   void Bootstrap(const string symbol, int blockBefore = 30, int blockAfter = 15)
   {
      Configure(symbol, "EconomicCalendar");
      m_blockMinsBefore = blockBefore;
      m_blockMinsAfter = blockAfter;
      m_lastCheck = 0;
      m_nearNews = false;
      m_minutesToNext = 999;
      m_nextEventName = "";
   }

   void SetBlockWindows(int before, int after)
   {
      m_blockMinsBefore = before;
      m_blockMinsAfter = after;
   }

   virtual bool Execute(SVPPipelineState &state) override
   {
      CVPModuleBase::Execute(state);

      // Throttle: only check every 60 seconds (calendar doesn't change faster)
      datetime now = TimeCurrent();
      if (now - m_lastCheck < 60 && m_lastCheck > 0)
      {
         state.news.isNearNews = m_nearNews;
         state.news.minutesToNews = m_minutesToNext;
         state.news.nextEventName = m_nextEventName;
         return true;
      }
      m_lastCheck = now;

      m_nearNews = false;
      m_minutesToNext = 999;
      m_nextEventName = "";

      // Scan calendar for high-impact events in window [now - blockAfter, now + blockBefore]
      datetime from = now - m_blockMinsAfter * 60;
      datetime to   = now + m_blockMinsBefore * 60;

      // Get currency from symbol (first 3 or last 3 chars)
      string base = StringSubstr(m_symbol, 0, 3);
      string quote = StringSubstr(m_symbol, 3, 3);

      MqlCalendarValue values[];
      int count = CalendarValueHistory(values, from, to);

      for (int i = 0; i < count; i++)
      {
         MqlCalendarEvent event;
         if (!CalendarEventById(values[i].event_id, event))
            continue;

         // Only high impact
         if (event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;

         // Must affect this symbol's currencies
         MqlCalendarCountry country;
         if (!CalendarCountryById(event.country_id, country))
            continue;

         string cur = country.currency;
         if (cur != base && cur != quote)
            continue;

         // Found relevant high-impact event in window
         int minsToEvent = (int)((values[i].time - now) / 60);
         m_nearNews = true;
         if (MathAbs(minsToEvent) < MathAbs(m_minutesToNext))
         {
            m_minutesToNext = minsToEvent;
            m_nextEventName = event.name;
         }
      }

      state.news.isNearNews = m_nearNews;
      state.news.minutesToNews = m_minutesToNext;
      state.news.nextEventName = m_nextEventName;
      state.news.nextImpact = m_nearNews ? NEWS_HIGH : NEWS_NONE;

      return true;
   }

   bool IsNearNews(void) const { return m_nearNews; }
};

#endif
