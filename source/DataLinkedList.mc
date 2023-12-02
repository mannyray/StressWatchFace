import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Activity;
using Toybox.Time.Gregorian as Tmg;

class InvalidStartingData extends Lang.Exception {
  var errorMessage as String = "";
  function initialize(errorMessage as String) {
    self.errorMessage = errorMessage;
    Exception.initialize();
  }

  function getErrorMessage() {
    return errorMessage;
  }
}

class DataPair {
  public var value as Number;
  public var time as Time.Moment;
  // if the field is no longer considered 'valid'/'fresh' for the context
  // DataPair is used in
  public var stale as Boolean;
  public function initialize(value as Number, time as Time.Moment) {
    self.value = value;
    self.time = time;
    self.stale = false;
  }
}

// Store the binCount number of data points for the last durationInMinutes.
class DataLinkedList {
  var saveName as String;
  const dataSuffixSaveName = "_data";
  const dataTimeSuffixSaveName = "_time";
  var durationInSeconds as Number;
  var binCount as Number;
  var approximateSecondDifferenceBetweenBins as Time.Duration;

  // if an entry is considered stale we set its value to 0
  public const staleValue = 0;
  // if we did not call addData in a while
  // then we will have to also add some values with value missingValue
  // in order to maintain approximateSecondDifferenceBetweenBins distance
  // beetween consecutive entries stored in data
  public const missingValue = 0;

  // we are implementing the linked list as a fixed size array
  // where the dataLastPointer points to the tail element:
  // ( dataLastPointer - 1 ) % data.size() is the freshest element:
  // example: for data = [z y x] we have dataLastPointer as 0
  // example: for data = [x z y] we have dataLastPointer as 1
  // This allows for rotation where if we pop/replace an element we can
  // shift dataLastPointer to ( dataLastPointer + 1 ) % data.size()
  // example: [z y x] we dataLastPointer = 0 and pop last element z and replace
  // with a fresh variable (a) to produce [a y x] then dataLastPointer = 1
  var data as Array<DataPair>;
  var dataLastPointer as Number = 0;

  // startingData: will be ordered from oldest to newest. binCount is defined based on startinData length
  //     We verify this and if not valid, throw InvalidStartingData.
  //     the last entry is thus assumed to be occuring at the 'current time'.
  // durationInMinutes: the expectation of the timespan from the 'current time' entry
  //     and the oldest entry. durationInMinutes and binCount have to be selected carefully
  //     such that when approximateSecondDifferenceBetweenBins = durationInMinutes*60/binCount is a non zero
  //     integer (otherwise InvalidStartingData error). If data between each entry in startingData is not spaced
  //     out by exactly approximateSecondDifferenceBetweenBins then we throw InvalidStartingData.
  // saveName: variable we will save the variable to persistent storage
  public function initialize(
    durationInMinutes as Number,
    startingData as Array<DataPair>,
    saveName as String
  ) {
    self.saveName = saveName;

    self.binCount = startingData.size();
    if (self.binCount < 2) {
      throw new InvalidStartingData("staringData is too small.");
    }
    self.dataLastPointer = 0;

    self.data = new Array<DataPair>[self.binCount];
    if ((durationInMinutes * 60) % (self.binCount - 1) != 0) {
      throw new InvalidStartingData(
        "The duration of each bin has to be a whole number in seconds."
      );
    }
    self.durationInSeconds = durationInMinutes * 60;

    // '-1' because (for example) if we have an array [a b c d] for startingData then
    // timeline this is presented by |--|--|--| where each "|" is when one of the a,b,c,d occurs
    self.approximateSecondDifferenceBetweenBins = new Time.Duration(
      (self.durationInSeconds / (self.binCount - 1)) as Number
    );
    // check the data in startingData is ordered from oldest to newest and make a local copy
    var currentTime = startingData[0].time;
    for (var i = 0; i < self.binCount; i++) {
      System.println(i + " - " + startingData[i].value);
      if (i < self.binCount - 1) {
        var nextTime = startingData[i + 1].time;
        if (currentTime.greaterThan(nextTime)) {
          var myFormat =
            "Entries not ordered in increasing time startingData[$1$] at $2$ compared to startingData[$3$] at $4$.";
          var myParams = [i, currentTime.value(), i + 1, nextTime.value()];
          throw new InvalidStartingData(Lang.format(myFormat, myParams));
        }

        if (
          (nextTime.subtract(currentTime) as Time.Duration).value() !=
          approximateSecondDifferenceBetweenBins.value()
        ) {
          var myFormat =
            "Entries should be spaced $1$ seconds apart. startingData[$2$] and startingData[$3$] is spaced $4$ seconds apart.";
          var myParams = [
            approximateSecondDifferenceBetweenBins.value(),
            i,
            i + 1,
            (nextTime.subtract(currentTime) as Time.Duration).value(),
          ];
          throw new InvalidStartingData(Lang.format(myFormat, myParams));
        }
        currentTime = nextTime;
      }
      self.data[i] = new DataPair(startingData[i].value, startingData[i].time);
    }
    markStale(currentTime);
  }

  // go through all entries in our data array and mark entries stale
  // that are older than compared to (currentTime - durationInSeconds).
  // return total amount of such stale entries
  private function markStale(currentTime as Time.Moment) as Number {
    var staleCount = 0;
    for (var i = dataLastPointer; i < self.binCount; i++) {
      // we subtract approximateSecondDifferenceBetweenBins due to off by one situation
      if (isTooOld(currentTime, self.data[i].time)) {
        self.data[i].stale = true;
        staleCount++;
      } else {
        return staleCount;
      }
    }
    for (var i = 0; i < dataLastPointer; i++) {
      if (isTooOld(currentTime, self.data[i].time)) {
        self.data[i].stale = true;
        staleCount++;
      } else {
        return staleCount;
      }
    }
    return staleCount;
  }

  public function addData(value as Number, time as Time.Moment) as Void {
    // mark stale elements in array if addData has not been called in a while
    // ideally staleCount is at most 1 as otherwise we are not calling
    // addData frequently enough. If staleCount is greater than 1
    // then that means we have not called addData in about staleCount*approximateSecondDifferenceBetweenBins.
    // We will therefore have to update dataLastPointer to point to the first non stale entry
    // while adding staleCount - 1 missing entries from the 'freshest' side with values that are
    // are essentially 'null'/missingValue
    var staleCount = markStale(time);

    // if there are no stale elements then this update is premature
    // as we would bump one stale element. We ignore this data.
    while (staleCount > 0) {
      var currentFreshestIndex =
        (self.dataLastPointer + self.binCount - 1) % self.binCount;

      var replacementValue = self.missingValue;
      if (staleCount == 1) {
        replacementValue = value;
      }
      // we set the time of the next entry to be approximateSecondDifferenceBetweenBins from past entry
      // it may be very likely that bumpTime does not exactly match inputted 'time' for when staleCount == 1.
      // This is fine as we are only holding an approximate time value to account for irregularirty and varying
      // frequency with which addData might be called
      var bumpTime = self.data[currentFreshestIndex].time.add(
        approximateSecondDifferenceBetweenBins
      );
      var newFreshestIndex = self.dataLastPointer;
      self.data[newFreshestIndex] = new DataPair(replacementValue, bumpTime);
      self.dataLastPointer = (self.dataLastPointer + 1) % self.binCount;
      staleCount = staleCount - 1;
    }
  }

  public function size() as Number {
    return data.size();
  }

  private function isTooOld(
    currentTime as Time.Moment,
    previousTime as Time.Moment
  ) as Boolean {
    return (currentTime.subtract(previousTime) as Time.Duration).greaterThan(
      new Time.Duration(self.durationInSeconds)
    );
  }

  // Save data to persistent storage
  public function backupData() as Void {
    var currentTime = Time.now();
    var dataValue = self.getOrderedArray(currentTime);
    var dataTime = self.getOrderedTimeArray(currentTime);
    Storage.setValue(self.saveName + self.dataSuffixSaveName, dataValue);
    Storage.setValue(self.saveName + self.dataTimeSuffixSaveName, dataTime);
  }

  public static function loadData(saveName as String) as Array<DataPair>? {
    var dataValue = Storage.getValue(saveName + self.dataSuffixSaveName);
    var dataTime = Storage.getValue(saveName + self.dataTimeSuffixSaveName);
    if (dataValue != null && dataTime != null) {
      var returnArray = new Array<DataPair>[dataTime.size()];
      for (var i = 0; i < dataTime.size(); i++) {
        returnArray[i] = new DataPair(
          dataValue[i],
          new Time.Moment(dataTime[i])
        );
      }
      return returnArray;
    } else {
      return null;
    }
  }

  // Given an array startingData where the data is increasing order (time wise) but with time difference between each consecutive entry
  // not matching durationInMinutes*60/(desiredBinCount-1) then we extrapolate the data to a new array which can be used as an argument to the constructor
  // of this class
  public static function interporalate(
    firstTime as Time.Moment,
    durationInMinutes as Number,
    desiredBinCount as Number,
    startingData as Array<DataPair>
  ) as Array<DataPair> {
    var desiredData = new Array<DataPair>[desiredBinCount];
    var approximateSecondDifferenceBetweenBins = new Time.Duration(
      ((durationInMinutes * 60) / (desiredBinCount - 1)) as Number
    );
    var currentTime = firstTime;
    for (var i = 0; i < desiredBinCount; i++) {
      desiredData[i] = new DataPair(0, currentTime);
      currentTime = currentTime.add(approximateSecondDifferenceBetweenBins);
    }

    var desiredDataIndex = 0;
    var desiredTime = desiredData[0].time;
    var startingDataIndex = 0;
    var startingDataTime = startingData[0].time;

    while (desiredDataIndex < desiredBinCount) {
      if (desiredTime.lessThan(startingDataTime)) {
        desiredData[desiredDataIndex].value =
          startingData[startingDataIndex].value;
        desiredDataIndex = desiredDataIndex + 1;
        desiredTime = desiredData[desiredDataIndex].time;
      } else {
        startingDataIndex = startingDataIndex + 1;
        if (startingDataIndex == startingData.size()) {
          for (var i = desiredDataIndex; i < desiredBinCount; i++) {
            desiredData[i].value = startingData[startingDataIndex - 1].value;
          }
          break;
        }
        startingDataTime = startingData[startingDataIndex].time;
      }
    }
    return desiredData;
  }

  public function getOrderedArray(currentTime as Time.Moment) as Array<Number> {
    // we don't mark stale in a get operation
    // data[dataLastPointer:] + data[:dataLastPointer-1]
    var returnArray = new Array<Number>[self.binCount];
    for (var i = self.dataLastPointer; i < self.binCount; i++) {
      if (!isTooOld(currentTime, self.data[i].time)) {
        returnArray[i - self.dataLastPointer] = self.data[i].value;
      } else {
        returnArray[i - self.dataLastPointer] = staleValue;
      }
    }
    for (var i = 0; i < self.dataLastPointer; i++) {
      if (!isTooOld(currentTime, self.data[i].time)) {
        returnArray[i + (self.binCount - self.dataLastPointer)] =
          self.data[i].value;
      } else {
        returnArray[i + (self.binCount - self.dataLastPointer)] = staleValue;
      }
    }
    return returnArray;
  }

  private function getOrderedTimeArray(
    currentTime as Time.Moment
  ) as Array<Number> {
    // sister function of getOrderedArray
    var returnArray = new Array<Number>[self.binCount];
    for (var i = self.dataLastPointer; i < self.binCount; i++) {
      returnArray[i - self.dataLastPointer] = self.data[i].time.value();
    }
    for (var i = 0; i < self.dataLastPointer; i++) {
      returnArray[i + (self.binCount - self.dataLastPointer)] =
        self.data[i].time.value();
    }
    return returnArray;
  }
}
