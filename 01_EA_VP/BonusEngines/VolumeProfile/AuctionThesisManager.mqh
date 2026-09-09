#ifndef __VP_EA_BONUS_AUCTIONTHESIS_SHIM_MQH__
#define __VP_EA_BONUS_AUCTIONTHESIS_SHIM_MQH__

//+------------------------------------------------------------------+
//| BonusEngines adapter shim for AuctionThesisManager                |
//|                                                                  |
//| The BonusEngines include "..\VolumeProfile\AuctionThesisManager" |
//| (resolving to BonusEngines\VolumeProfile\AuctionThesisManager).  |
//| The VP EA already has a full CAuctionThesisManager with exactly  |
//| the methods the engines call (Reset, GetArchetype, InitTrade,    |
//| Evaluate) plus EEntryArchetype and SThesisOutput. So this shim   |
//| simply re-exports the real implementation — no stub needed.      |
//+------------------------------------------------------------------+

#include "..\..\02_VolumeProfile\AuctionThesisManager.mqh"

#endif
