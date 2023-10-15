#include <FairLogger.h>
#include <QualityControl/MonitorObject.h>

#include <TFile.h>
#include <TH1.h>
#include <TH2.h>
#include <TMath.h>
#include <TObjArray.h>

#include <fstream>
#include <iostream>
#include <memory>

/// \file PrintAgingQcHistograms.C
/// \brief This script prints the means, stddev's and bin contents of the aging QC histograms to a CSV file.

using namespace o2::quality_control::core;

/// Pull out the object of type T from a MonitorObject collection,
/// i.e. an acutal histogram contained in a MonitorObject.
template <typename T>
T* GetObjectFromMOs(TObjArray* moCollection, const char* name)
{
  MonitorObject* mo = dynamic_cast<MonitorObject*>(moCollection->FindObject(name));
	if (!mo) {
		LOG(error) << "MonitorObject '" << name << "' not found in the input file.";
		return nullptr;
	}
  T* obj = dynamic_cast<T*>(mo->getObject());
  return obj;
}

std::pair<double, double> GetMeanAndStddev(TH1* hist, bool amp, int nBins = 0) {
  // TODO: fit time histograms with a Gaussian and get the mean and stddev from the fit
  double mean = 0.0;
  double stddev = 0.0;
  double sumSquared = 0.0;
  double weightSum = 0.0;

  // Cut out low amplitude bins (8 ADC channels and below)
  int lowBin = amp ? 110 : 1;
  int highBin = nBins;

  for (int iBin = lowBin; iBin <= highBin; iBin++) {
    int binCount = hist->GetBinContent(iBin);
    double binValue = hist->GetBinLowEdge(iBin);
    mean += binValue * binCount;
    sumSquared += binValue * binValue * binCount;
    weightSum += binCount;
  }

  if (weightSum > 0) {
    mean = mean / weightSum;
    stddev = TMath::Sqrt((sumSquared / weightSum) - (mean * mean));
  } else {
    mean = 0.0;
    stddev = 0.0;
  }

  return { mean , stddev };
}

int WriteHistogramsToCSV(const char* outputFileName, TObjArray* histograms, bool amp = true) {
  // Open the output CSV file for writing
  std::ofstream fCsv(outputFileName);

  // Check if the file opened successfully
  if (!fCsv.is_open()) {
    std::cout << "Unable to open CSV file for writing." << std::endl;
    return 1;
  }

  int nHistograms = histograms->GetEntries();
  TH1* histogram = dynamic_cast<TH1*>(histograms->At(0));
  // Get the number of bins from the first histogram (assuming all histograms have the same binning)
  int nBins = histogram->GetNbinsX(); 

  fCsv << (amp ? "ADC ch" : "TDC ch") << ",";
  fCsv << "Mean" << ",";
  fCsv << "Stddev" << ",";

  for (int iBin = 1; iBin <= nBins; iBin++) {
    fCsv << histogram->GetBinLowEdge(iBin) << ",";
  }

  fCsv << "\n";

  for (int iHistogram = 0; iHistogram < nHistograms; iHistogram++) {
    histogram = dynamic_cast<TH1*>(histograms->At(iHistogram));
    if (!histogram) {
      std::cout << "Dynamic cast failed for histogram " << iHistogram << " " << iHistogram << std::endl;
      // std::cout << "Dynamic cast failed for histogram " << histograms->At(iHistogram)->GetName() << " " << iHistogram << std::endl;
      continue;
    }
    std::pair<double, double> meanAndStddev = GetMeanAndStddev(histogram, amp, nBins);

    fCsv << histogram->GetName() << ",";
    fCsv << meanAndStddev.first << ",";
    fCsv << meanAndStddev.second << ",";

    for (int iBin = 1; iBin <= nBins; iBin++) {
      fCsv << histogram->GetBinContent(iBin);
      if (iBin < nBins) {
        fCsv << ",";
      }
    }

    fCsv << "\n";
  }

  fCsv.close();
  std::cout << "CSV file '" << outputFileName << "' has been created." << std::endl;
  return 0;
}

int PrintAgingQcHistograms(const char* inputFileName,
                            const char* outputFileName,
                            bool amp = true)
{
  // Open the input file and get the collection of MonitorObjects
  std::unique_ptr<TFile> fInput(TFile::Open(inputFileName, "READ"));
  if (!fInput) {
    std::cout << "Unable to open input file '" << inputFileName << "'." << std::endl;
    return 1;
  }
  TObjArray* moCollection = fInput->Get<TObjArray>("FT0/AgingLaser");

  // 1D histograms to be printed
  TObjArray* histograms = new TObjArray();

  if (amp) {
    for (int iADC = 0; iADC <= 1; iADC++) {
      TH2* hAmpPerChannel = GetObjectFromMOs<TH2>(moCollection, Form("AmpPerChannelADC%i", iADC));
      for (int iChId = 0; iChId <= 207; iChId++) {
        histograms->Add(hAmpPerChannel->ProjectionY(Form("AmpCh%iADC%i", iChId, iADC), iChId+1, iChId+1));
      }
    }
    // Reference peaks
    for (int iChId = 208; iChId <= 211; iChId++) {
      for (int iPeak = 1; iPeak <= 2; iPeak++) {
        for (int iADC = 0; iADC <= 1; iADC++) {
          TH2* hAmpPerChannel = GetObjectFromMOs<TH2>(moCollection, Form("AmpPerChannelPeak%iADC%i", iPeak, iADC));
          histograms->Add(hAmpPerChannel->ProjectionY(Form("AmpCh%iPeak%iADC%i", iChId, iPeak, iADC), iChId+1, iChId+1));
        }
      }
    }
  } else {
    TH2* hTimePerChannel = GetObjectFromMOs<TH2>(moCollection, "TimePerChannel");
    for (int iChId = 0; iChId <= 207; iChId++) {
      histograms->Add(hTimePerChannel->ProjectionY(Form("TimeCh%i", iChId), iChId+1, iChId+1));
    }

    // Reference peaks
    for (int iChId = 208; iChId <= 211; iChId++) {
      for (int iPeak = 1; iPeak <= 2; iPeak++) {
        hTimePerChannel = GetObjectFromMOs<TH2>(moCollection, Form("TimePerChannelPeak%i", iPeak));
        histograms->Add(hTimePerChannel->ProjectionY(Form("TimeCh%iPeak%i", iChId, iPeak), iChId+1, iChId+1));
      }
    }
  }

  // Write the histograms' bin contents to the CSV file
  WriteHistogramsToCSV(outputFileName, histograms, amp);

  // Clean up
  delete histograms;
  fInput->Close();

  return 0;
}