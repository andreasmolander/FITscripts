#if !defined( __CINT__) || defined (__MAKECINT__)

#ifndef ROOT_TStyle
#include "TStyle.h"
#endif

#endif

void logxlogy()
{
   gStyle->SetOptLogx(1);
   gStyle->SetOptLogy(1);
}
