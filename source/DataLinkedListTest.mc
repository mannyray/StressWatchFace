using Toybox.Test as Test;
import Toybox.System;
import Toybox.Lang;
using Toybox.Time;

function arrayToString(arr as Array<Number>) as String {
  var result = "";
  for (var i = 0; i < arr.size(); i++) {
    result = result + arr[i] + " ";
  }
  return result;
}

function assertArraysEqual(
  expected as Array<Number>,
  recieved as Array<Number>
) as Void {
  Test.assert(expected.size() == recieved.size());
  for (var i = 0; i < expected.size(); i++) {
    Test.assertMessage(
      expected[i] == recieved[i],
      "expected: " +
        arrayToString(expected) +
        ", received: " +
        arrayToString(recieved)
    );
  }
}

(:test)
function testBinDurationWholeSeconds(logger as Toybox.Test.Logger) as Boolean {
  var startingData = new Array<DataPair>[4];
  var durationDifference = new Time.Duration(60);
  var timeNow = Time.now();
  startingData[0] = new DataPair(10, timeNow);
  startingData[1] = new DataPair(11, timeNow.add(new Time.Duration(61)));
  startingData[2] = new DataPair(
    12,
    timeNow.add(new Time.Duration(61)).add(new Time.Duration(61))
  );
  startingData[3] = new DataPair(
    13,
    timeNow
      .add(new Time.Duration(60))
      .add(new Time.Duration(60))
      .add(new Time.Duration(60))
  );

  var arr = DataLinkedList.interporalate(
    timeNow.subtract(new Time.Duration(10)),
    6,
    13,
    startingData
  );

  Test.assertMessage(
    arr.size() == 13,
    "Expected length 13 but was " + arr.size()
  );
  var currentTime = timeNow.subtract(new Time.Duration(10));
  var comparisonArr = new Array<Number>[13];
  for (var i = 0; i < arr.size(); i++) {
    Test.assertMessage(
      arr[i].time.value() == currentTime.value(),
      "For index " +
        i +
        " Got: " +
        arr[i].time.value() +
        " but expected " +
        currentTime.value()
    );
    currentTime = currentTime.add(new Time.Duration(30));
    comparisonArr[i] = arr[i].value;
  }

  assertArraysEqual(
    [10, 11, 11, 12, 12, 13, 13, 13, 13, 13, 13, 13, 13],
    comparisonArr
  );

  return true;
}

(:test)
function testInvalidlySpacedOutEntries(
  logger as Toybox.Test.Logger
) as Boolean {
  var startingData = new Array<DataPair>[4];
  var durationDifference = new Time.Duration(60);
  var timeNow = Time.now();
  startingData[0] = new DataPair(10, timeNow);
  startingData[1] = new DataPair(11, timeNow.add(durationDifference));
  startingData[2] = new DataPair(
    12,
    timeNow.add(durationDifference).add(durationDifference)
  );
  startingData[3] = new DataPair(
    13,
    timeNow
      .add(durationDifference)
      .add(durationDifference)
      .add(durationDifference)
      .add(durationDifference)
  );
  try {
    new DataLinkedList(3, startingData, "file");
  } catch (e instanceof InvalidStartingData) {
    var acquiredErrorMessage = e.getErrorMessage();
    var expectedErrorMessage =
      "Entries should be spaced 60 seconds apart. startingData[2] and startingData[3] is spaced 120 seconds apart";
    Test.assertMessage(
      acquiredErrorMessage.find(expectedErrorMessage) != null,
      "Invalid error message. Got '" +
        acquiredErrorMessage +
        "', expected: '" +
        expectedErrorMessage +
        "'"
    );
    return true;
  }
  return false;
}

(:test)
function testInvalidlyOrderedEntries(logger as Toybox.Test.Logger) as Boolean {
  var startingData = new Array<DataPair>[4];
  var durationDifference = new Time.Duration(60);
  var timeNow = Time.now();
  startingData[1] = new DataPair(10, timeNow);
  startingData[0] = new DataPair(11, timeNow.add(durationDifference));
  startingData[2] = new DataPair(
    12,
    timeNow.add(durationDifference).add(durationDifference)
  );
  startingData[3] = new DataPair(
    13,
    timeNow
      .add(durationDifference)
      .add(durationDifference)
      .add(durationDifference)
  );
  try {
    new DataLinkedList(3, startingData, "file");
  } catch (e instanceof InvalidStartingData) {
    var acquiredErrorMessage = e.getErrorMessage();
    var myFormat =
      "Entries not ordered in increasing time startingData[0] at $1$ compared to startingData[1] at $2$.";
    var myParams = [timeNow.add(durationDifference).value(), timeNow.value()];
    var expectedErrorMessage = Lang.format(myFormat, myParams);
    Test.assertMessage(
      acquiredErrorMessage.find(expectedErrorMessage) != null,
      "Invalid error message. Got '" +
        acquiredErrorMessage +
        "', expected: '" +
        expectedErrorMessage +
        "'"
    );
    return true;
  }
  return false;
}

(:test)
function testProperInitializationAndExtraction(
  logger as Toybox.Test.Logger
) as Boolean {
  var startingData = new Array<DataPair>[4];
  var durationDifference = new Time.Duration(60);
  var timeNow = Time.now();
  var lastTime = timeNow
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference); // durationDifference*3
  startingData[0] = new DataPair(10, timeNow);
  startingData[1] = new DataPair(11, timeNow.add(durationDifference));
  startingData[2] = new DataPair(
    12,
    timeNow.add(durationDifference).add(durationDifference)
  );
  startingData[3] = new DataPair(13, lastTime);
  var dataLinkedList = new DataLinkedList(3, startingData, "file");

  var arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([10, 11, 12, 13], arr);
  arr = dataLinkedList.getOrderedArray(lastTime.add(new Time.Duration(1)));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = dataLinkedList.getOrderedArray(lastTime.add(new Time.Duration(59)));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = dataLinkedList.getOrderedArray(lastTime.add(durationDifference));
  assertArraysEqual([0, 11, 12, 13], arr);
  arr = dataLinkedList.getOrderedArray(
    lastTime.add(durationDifference).add(new Time.Duration(1))
  );
  assertArraysEqual([0, 0, 12, 13], arr);

  lastTime = lastTime.add(durationDifference).add(new Time.Duration(1)); // durationDifference*4 + 1
  dataLinkedList.addData(14, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(1)); // durationDifference*4 + 2
  dataLinkedList.addData(15, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(58)); // durationDifference*5
  dataLinkedList.addData(15, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([12, 13, 0, 14], arr);

  lastTime = lastTime.add(new Time.Duration(1)); //duration*5 + 1
  dataLinkedList.addData(15, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([13, 0, 14, 15], arr);

  lastTime = lastTime
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference); //duration*8 + 1
  dataLinkedList.addData(16, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([15, 0, 0, 16], arr);

  lastTime = lastTime
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference)
    .add(durationDifference); //duration*14 + 1
  dataLinkedList.addData(17, lastTime);
  arr = dataLinkedList.getOrderedArray(lastTime);
  assertArraysEqual([0, 0, 0, 17], arr);

  return true;
}
