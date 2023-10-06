#if !defined( __CINT__) || defined (__MAKECINT__)

#ifndef ROOT_TStyle
#include "TStyle.h"
#endif

#endif

void logylogz()
{
    gStyle->SetOptLogy(1);
    gStyle->SetOptLogz(1);
}
