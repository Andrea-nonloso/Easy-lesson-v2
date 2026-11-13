import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: speechSynthesis del browser.
bool get webTtsSupported => globalContext.has('speechSynthesis');

void webSpeak(String text, String lang, double rate) {
  final synth = globalContext.getProperty<JSObject>('speechSynthesis'.toJS);
  synth.callMethod<JSAny?>('cancel'.toJS);
  final ctor = globalContext.getProperty<JSFunction>('SpeechSynthesisUtterance'.toJS);
  final u = ctor.callAsConstructor<JSObject>(text.toJS);
  u.setProperty('lang'.toJS, lang.toJS);
  u.setProperty('rate'.toJS, rate.toJS);
  synth.callMethod<JSAny?>('speak'.toJS, u);
}

void webStop() {
  if (!webTtsSupported) return;
  globalContext.getProperty<JSObject>('speechSynthesis'.toJS).callMethod<JSAny?>('cancel'.toJS);
}
