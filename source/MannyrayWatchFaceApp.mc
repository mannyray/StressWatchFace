import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.Application.Storage;
using Toybox.Time;

class MannyrayWatchFaceApp extends Application.AppBase {
  var minutesToTrackHeartBeat;
  var dataDensityForHeartTrack;
  var graphTicks;

  var allDataStaleLimit = 2;

  var heartData;
  var variableForHeartData;
  var xAxisTitle;

  function initialize() {
    AppBase.initialize();

    minutesToTrackHeartBeat = 3;
    if (minutesToTrackHeartBeat == 10) {
      dataDensityForHeartTrack = 201;
    } else if (minutesToTrackHeartBeat == 3) {
      dataDensityForHeartTrack = 181;
    } else if (minutesToTrackHeartBeat == 5) {
      dataDensityForHeartTrack = 151;
    }
    xAxisTitle = "last " + minutesToTrackHeartBeat + " minutes";
    graphTicks = minutesToTrackHeartBeat;
    variableForHeartData = "heartData" + minutesToTrackHeartBeat;
  }

  function getCorrectInitialData() as Array<DataPair> {
    var currentTime = Time.now();
    var history = DataLinkedList.loadData(variableForHeartData);

    // check that the freshest element of previously recorded data is not too stale (if it even exists)
    // otherwise interpolate previous heart history that by default is sparsely recorded
    if (
      history == null ||
      (
        currentTime.subtract(history[history.size() - 1].time) as Time.Duration
      ).greaterThan(new Time.Duration(allDataStaleLimit * 60))
    ) {
      history = getHeartHistory(minutesToTrackHeartBeat);
    } else {
      return history;
    }
    return DataLinkedList.interporalate(
      currentTime.subtract(new Time.Duration(minutesToTrackHeartBeat * 60)),
      minutesToTrackHeartBeat,
      dataDensityForHeartTrack,
      history
    );
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {}

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {}

  // Return the initial view of your application here
  function getInitialView() as Array<Views or InputDelegates>? {
    //return [ new MannyrayWatchFaceView(heartData) ] as Array<Views or InputDelegates>;
    if (Toybox.WatchUi.WatchFace has :onPartialUpdate) {
      // onPartialUpdate exists
      return [
        new MannyrayWatchFaceView(
          new DataLinkedList(
            minutesToTrackHeartBeat,
            getCorrectInitialData(),
            variableForHeartData
          ),
          xAxisTitle,
          graphTicks
        ),
        new MannyrayWatchDelegate(),
      ];
    } else {
      return [
        new MannyrayWatchFaceView(
          new DataLinkedList(
            minutesToTrackHeartBeat,
            getCorrectInitialData(),
            variableForHeartData
          ),
          xAxisTitle,
          graphTicks
        ),
      ];
    }
  }

  // New app settings have been received so trigger a UI update
  function onSettingsChanged() as Void {
    WatchUi.requestUpdate();
  }
}

function getApp() as MannyrayWatchFaceApp {
  return Application.getApp() as MannyrayWatchFaceApp;
}
