<script type="text/javascript">
document.addEventListener ("DOMContentLoaded", () => {
	const warningmsgDOMElement = document.getElementById("conflictwarning");
	const potentialConflicts = {};

	let req1DOMelement = document.querySelector('[name="itemparameter_request1fromuser"]');
	let req2DOMelement = document.querySelector('[name="itemparameter_request2fromuser"]');
	if (req1DOMelement) { req1DOMelement.addEventListener('change', reqchangeHandler, false); }
	if (req2DOMelement) { req2DOMelement.addEventListener('change', reqchangeHandler, false); }

	let neverplayedDOMElement = document.querySelector('[name="itemparameter_playedbefore"]');
	let recentlyplayedDOMElement = document.querySelector('[name="itemparameter_recentlyplayed"]');
	if (neverplayedDOMElement) { neverplayedDOMElement.addEventListener('change', playedchangeHandler, false); }
	if (recentlyplayedDOMElement) { recentlyplayedDOMElement.addEventListener('change', playedchangeHandler, false); }

	let minyearDOMelement = document.querySelector('[name="itemparameter_minyear"]');
	let maxyearDOMelement = document.querySelector('[name="itemparameter_maxyear"]');
	if (minyearDOMelement) { minyearDOMelement.addEventListener('change', reqchangeHandler, false); }
	if (maxyearDOMelement) { maxyearDOMelement.addEventListener('change', reqchangeHandler, false); }

	let includedartistsDOMelement = document.querySelector('[name="itemparameter_includedartists"]');
	let excludedartistsDOMelement = document.querySelector('[name="itemparameter_excludedartists"]');
	if (includedartistsDOMelement) { includedartistsDOMelement.addEventListener('change', reqchangeHandler, false); }
	if (excludedartistsDOMelement) { excludedartistsDOMelement.addEventListener('change', reqchangeHandler, false); }

	let includedgenresDOMelements = document.querySelectorAll('[name^="itemparameter_includedgenres"]');
	let excludedgenresDOMelements = document.querySelectorAll('[name^="itemparameter_excludedgenres"]');
	let noofincludedgenres = 0;
	let noofexcludedgenres = 0;

	if (includedgenresDOMelements.length > 0) {
		includedgenresDOMelements.forEach((item) => {
			// count saved checked included genre items
			if (item.checked) { noofincludedgenres++; }
			item.addEventListener('change', e => {
						e.target.checked ? noofincludedgenres++ : noofincludedgenres--;
							if (noofincludedgenres < 0) {
								noofincludedgenres = 0;
							}
						reqchangeHandler();
			})
		})
	}
	if (excludedgenresDOMelements.length > 0) {
		excludedgenresDOMelements.forEach((item) => {
			// count saved checked excluded genre items
			if (item.checked) { noofexcludedgenres++; }
			item.addEventListener('change', e => {
						if(e.target.checked) {
							noofexcludedgenres++;
						} else {
							noofexcludedgenres--;
							if (noofexcludedgenres < 0) {
								noofexcludedgenres = 0;
							}
						}
						reqchangeHandler();
			})
		})
	}

	let activeClientVLDOMElement = document.querySelector('[name="itemparameter_activevirtuallibrary"]');
	let permanentVLDOMElement = document.querySelector('[name="itemparameter_virtuallibrary"]');

	function reqchangeHandler() {
		// conflict: dupe requests
		if (req1DOMelement && req2DOMelement && req1DOMelement.value != '' && req2DOMelement.value != '' && req1DOMelement.value == req2DOMelement.value) {
			document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
			document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
			warningmsgDOMElement.style = 'visibility:visible;';
			potentialConflicts.dupeuserrequests = 1;
		}
		if (req1DOMelement && req2DOMelement && (req1DOMelement.value == '' || req2DOMelement.value == '' || req1DOMelement.value != req2DOMelement.value)) {
			if (!("lastplayedrequest1" in potentialConflicts)) { document.getElementById('warning_request1fromuser').style = 'visibility:hidden;'; }
			if (!("lastplayedrequest2" in potentialConflicts)) { document.getElementById('warning_request2fromuser').style = 'visibility:hidden;'; }
			delete potentialConflicts.dupeuserrequests;
			if (Object.keys(potentialConflicts).length == 0) {
				warningmsgDOMElement.style = 'visibility:hidden;';
			}
		}

		if (req1DOMelement) {
			// reset warnings
			if (!("dupeuserrequests" in potentialConflicts)) {
				document.getElementById('warning_request1fromuser').style = 'visibility:hidden;';
			}
			if (!("playedbefore" in potentialConflicts) && !("lastplayedrequest2" in potentialConflicts)) {
				if (neverplayedDOMElement) { document.getElementById('warning_playedbefore').style = 'visibility:hidden;'; }
			}
			if (!("yearrequest2" in potentialConflicts)) {
				if (minyearDOMelement) { document.getElementById('warning_minyear').style = 'visibility:hidden;'; }
				if (maxyearDOMelement) { document.getElementById('warning_maxyear').style = 'visibility:hidden;'; }
			}
			if (!("artistrequest2" in potentialConflicts)) {
				if (includedartistsDOMelement) { document.getElementById('warning_includedartists').style = 'visibility:hidden;'; }
				if (excludedartistsDOMelement) { document.getElementById('warning_excludedartists').style = 'visibility:hidden;'; }
			}
			if (!("genrerequest2" in potentialConflicts)) {
				if (includedgenresDOMelements.length > 0) { document.getElementById('warning_includedgenres').style = 'visibility:hidden;'; }
				if (excludedgenresDOMelements.length > 0) { document.getElementById('warning_excludedgenres').style = 'visibility:hidden;'; }
			}
			if (!("virtuallibs" in potentialConflicts)) {
				if (activeClientVLDOMElement) { document.getElementById('warning_activevirtuallibrary').style = 'visibility:hidden;'; }
				if (permanentVLDOMElement) { document.getElementById('warning_virtuallibrary').style = 'visibility:hidden;'; }
			}
			// conflict: req lastplayed vs neverplayed
			if (req1DOMelement.value == 'lastplayed' && neverplayedDOMElement && neverplayedDOMElement.value == 1) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_playedbefore').style = 'visibility:visible;';
				potentialConflicts.lastplayedrequest1 = 1;
			// conflict: req (multiple)decades/years vs minyear/maxyear
			} else if (((req1DOMelement.value == 'decade' || req1DOMelement.value == 'multipledecades' || req1DOMelement.value == 'year' || req1DOMelement.value == 'multipleyears')) && ((minyearDOMelement && minyearDOMelement.value != '') || (maxyearDOMelement && maxyearDOMelement.value != ''))) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_minyear').style = 'visibility:hidden;';
				document.getElementById('warning_maxyear').style = 'visibility:hidden;';
				if (minyearDOMelement && minyearDOMelement.value != '') { document.getElementById('warning_minyear').style = 'visibility:visible;'; }
				if (maxyearDOMelement && maxyearDOMelement.value != '') { document.getElementById('warning_maxyear').style = 'visibility:visible;'; }
				potentialConflicts.yearrequest1 = 1;
			// conflict: req artist vs includedartists/excludedartists
			} else if (req1DOMelement.value == 'artist' && ((includedartistsDOMelement && includedartistsDOMelement.value != '') || (excludedartistsDOMelement && excludedartistsDOMelement.value != ''))) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_includedartists').style = 'visibility:hidden;';
				document.getElementById('warning_excludedartists').style = 'visibility:hidden;';
				if (includedartistsDOMelement && includedartistsDOMelement.value != '') { document.getElementById('warning_includedartists').style = 'visibility:visible;'; }
				if (excludedartistsDOMelement && excludedartistsDOMelement.value != '') { document.getElementById('warning_excludedartists').style = 'visibility:visible;'; }
				potentialConflicts.artistrequest1 = 1;
			// conflict: req (multiple)genres vs includedgenres
			} else if ((req1DOMelement.value == 'genre' || req1DOMelement.value == 'multiplegenres') && ((includedgenresDOMelements.length > 0 && noofincludedgenres > 0) || (excludedgenresDOMelements.length > 0 && noofexcludedgenres > 0))) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_includedgenres').style = 'visibility:hidden;';
				document.getElementById('warning_excludedgenres').style = 'visibility:hidden;';
				if (noofincludedgenres > 0) { document.getElementById('warning_includedgenres').style = 'visibility:visible;'; }
				if (noofexcludedgenres > 0) { document.getElementById('warning_excludedgenres').style = 'visibility:visible;'; }
				potentialConflicts.genrerequest1 = 1;
			// conflict: req VL vs active client VL + permanently selected VL
			} else if (req1DOMelement.value == 'virtuallibrary' && ((activeClientVLDOMElement && activeClientVLDOMElement.checked) || (permanentVLDOMElement && permanentVLDOMElement.value != ''))) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_activevirtuallibrary').style = 'visibility:hidden;';
				document.getElementById('warning_virtuallibrary').style = 'visibility:hidden;';
				if (activeClientVLDOMElement && activeClientVLDOMElement.checked) { document.getElementById('warning_activevirtuallibrary').style = 'visibility:visible;'; }
				if (permanentVLDOMElement && permanentVLDOMElement.value != '') { document.getElementById('warning_virtuallibrary').style = 'visibility:visible;'; }
				potentialConflicts.vlibrequest1 = 1;
			} else {
				delete potentialConflicts.lastplayedrequest1;
				delete potentialConflicts.yearrequest1;
				delete potentialConflicts.artistrequest1;
				delete potentialConflicts.genrerequest1;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		}
		if (req2DOMelement) {
			// reset warnings
			if (!("dupeuserrequests" in potentialConflicts)) {
				document.getElementById('warning_request2fromuser').style = 'visibility:hidden;';
			}
			if (!("playedbefore" in potentialConflicts) && !("lastplayedrequest1" in potentialConflicts)) {
				if (neverplayedDOMElement) { document.getElementById('warning_playedbefore').style = 'visibility:hidden;'; }
			}
			if (!("yearrequest1" in potentialConflicts)) {
				if (minyearDOMelement) { document.getElementById('warning_minyear').style = 'visibility:hidden;'; }
				if (maxyearDOMelement) { document.getElementById('warning_maxyear').style = 'visibility:hidden;'; }
			}
			if (!("artistrequest1" in potentialConflicts)) {
				if (includedartistsDOMelement) { document.getElementById('warning_includedartists').style = 'visibility:hidden;'; }
				if (excludedartistsDOMelement) { document.getElementById('warning_excludedartists').style = 'visibility:hidden;'; }
			}
			if (!("genrerequest1" in potentialConflicts)) {
				if (includedgenresDOMelements.length > 0) { document.getElementById('warning_includedgenres').style = 'visibility:hidden;'; }
				if (excludedgenresDOMelements.length > 0) { document.getElementById('warning_excludedgenres').style = 'visibility:hidden;'; }
			}
			// conflict: req lastplayed vs neverplayed
			if (req2DOMelement.value == 'lastplayed' && neverplayedDOMElement.value == 1) {
				document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_playedbefore').style = 'visibility:visible;';
				potentialConflicts.lastplayedrequest2 = 1;
			// conflict: req (multiple)decades/years vs minyear/maxyear
			} else if (((req2DOMelement.value == 'decade' || req2DOMelement.value == 'multipledecades' || req2DOMelement.value == 'year' || req2DOMelement.value == 'multipleyears')) && ((minyearDOMelement && minyearDOMelement.value != '') || (maxyearDOMelement && maxyearDOMelement.value != ''))) {
				document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_minyear').style = 'visibility:hidden;';
				document.getElementById('warning_maxyear').style = 'visibility:hidden;';
				if (minyearDOMelement && minyearDOMelement.value != '') { document.getElementById('warning_minyear').style = 'visibility:visible;'; }
				if (maxyearDOMelement && maxyearDOMelement.value != '') { document.getElementById('warning_maxyear').style = 'visibility:visible;'; }
				potentialConflicts.yearrequest2 = 1;
			// conflict: req artist vs includedartists/excludedartists
			} else if (req2DOMelement.value == 'artist' && ((includedartistsDOMelement && includedartistsDOMelement.value != '') || (excludedartistsDOMelement && excludedartistsDOMelement.value != ''))) {
				document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_includedartists').style = 'visibility:hidden;';
				document.getElementById('warning_excludedartists').style = 'visibility:hidden;';
				if (includedartistsDOMelement && includedartistsDOMelement.value != '') { document.getElementById('warning_includedartists').style = 'visibility:visible;'; }
				if (excludedartistsDOMelement && excludedartistsDOMelement.value != '') { document.getElementById('warning_excludedartists').style = 'visibility:visible;'; }
				potentialConflicts.artistrequest2 = 1;
			// conflict: req (multiple)genres vs includedgenres
			} else if ((req2DOMelement.value == 'genre' || req2DOMelement.value == 'multiplegenres') && ((includedgenresDOMelements.length > 0 && noofincludedgenres > 0) || (excludedgenresDOMelements.length > 0 && noofexcludedgenres > 0))) {
				document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_includedgenres').style = 'visibility:hidden;';
				document.getElementById('warning_excludedgenres').style = 'visibility:hidden;';
				if (noofincludedgenres > 0) { document.getElementById('warning_includedgenres').style = 'visibility:visible;'; }
				if (noofexcludedgenres > 0) { document.getElementById('warning_excludedgenres').style = 'visibility:visible;'; }
				potentialConflicts.genrerequest2 = 1;
			} else {
				delete potentialConflicts.lastplayedrequest2;
				delete potentialConflicts.yearrequest2;
				delete potentialConflicts.artistrequest2;
				delete potentialConflicts.genrerequest2;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		}
	}

	function playedchangeHandler() {
		// conflict: lastplayed vs neverplayed
		if (req1DOMelement) {
			if (req1DOMelement.value == 'lastplayed' && neverplayedDOMElement.value == 1) {
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_playedbefore').style = 'visibility:visible;';
				potentialConflicts.lastplayedrequest1 = 1;
			} else if (neverplayedDOMElement.value != 1) {
				if (!("dupeuserrequests" in potentialConflicts) && !("vlibrequest1" in potentialConflicts) && !("yearrequest1" in potentialConflicts) && !("artistrequest1" in potentialConflicts) && !("genrerequest1" in potentialConflicts)) {
					document.getElementById('warning_request1fromuser').style = 'visibility:hidden;';
				}
				if (!("playedbefore" in potentialConflicts) && !("lastplayedrequest2" in potentialConflicts)) {
					document.getElementById('warning_playedbefore').style = 'visibility:hidden;';
				}
				delete potentialConflicts.lastplayedrequest1;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		}
		if (req2DOMelement) {
			if (req2DOMelement.value == 'lastplayed' && neverplayedDOMElement.value == 1) {
				document.getElementById('warning_request2fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_playedbefore').style = 'visibility:visible;';
				potentialConflicts.lastplayedrequest2 = 1;
			} else if (neverplayedDOMElement.value != 1) {
				if (!("dupeuserrequests" in potentialConflicts) && !("vlibrequest2" in potentialConflicts) && !("yearrequest2" in potentialConflicts) && !("artistrequest2" in potentialConflicts) && !("genrerequest2" in potentialConflicts)) {
					document.getElementById('warning_request2fromuser').style = 'visibility:hidden;';
				}
				if (!("playedbefore" in potentialConflicts) && !("lastplayedrequest1" in potentialConflicts)) {
					document.getElementById('warning_playedbefore').style = 'visibility:hidden;';
				}
				delete potentialConflicts.lastplayedrequest2;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		}
		// conflict: neverplayed (playedbefore = 1) vs recentlyplayed
		if (recentlyplayedDOMElement && neverplayedDOMElement && recentlyplayedDOMElement.value != '' && neverplayedDOMElement.value == 1) {
			document.getElementById('warning_playedbefore').style = 'visibility:visible;';
			document.getElementById('warning_recentlyplayed').style = 'visibility:visible;';
			warningmsgDOMElement.style = 'visibility:visible;';
			potentialConflicts.playedbefore = 1;
		} else if (recentlyplayedDOMElement && neverplayedDOMElement && (recentlyplayedDOMElement.value == '' || neverplayedDOMElement.value != 1)){
			if (!("lastplayedrequest1" in potentialConflicts) && !("lastplayedrequest2" in potentialConflicts)) {
				document.getElementById('warning_playedbefore').style = 'visibility:hidden;';
			}
			document.getElementById('warning_recentlyplayed').style = 'visibility:hidden;';
			delete potentialConflicts.playedbefore;
			if (Object.keys(potentialConflicts).length == 0) {
				warningmsgDOMElement.style = 'visibility:hidden;';
			}
		}
	}

	// conflict: minrating + exactrating
	let minRatingDOMElement = document.querySelector('[name="itemparameter_minrating"]');
	let exactRatingDOMElement = document.querySelector('[name="itemparameter_exactrating"]');
	if (exactRatingDOMElement && minRatingDOMElement) {
		minRatingDOMElement.addEventListener('change', changeHandler, false);
		exactRatingDOMElement.addEventListener('change', changeHandler, false);
		function changeHandler() {
			if (minRatingDOMElement.value != '' && exactRatingDOMElement.value != '') {
				document.getElementById('warning_minrating').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_exactrating').style = 'visibility:visible;';
				potentialConflicts.minexactrating = 1;
			} else {
				document.getElementById('warning_minrating').style = 'visibility:hidden;';
				document.getElementById('warning_exactrating').style = 'visibility:hidden;';
				delete potentialConflicts.minexactrating;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}

		}
	}

	// conflict: MINdpsv + MAXdpsv
	let minDpsvDOMElement = document.querySelector('[name="itemparameter_mindpsv"]');
	let maxDpsvDOMElement = document.querySelector('[name="itemparameter_maxdpsv"]');
	if (minDpsvDOMElement && maxDpsvDOMElement) {
		minDpsvDOMElement.addEventListener('change', changeHandler, false);
		maxDpsvDOMElement.addEventListener('change', changeHandler, false);
		function changeHandler() {
			if (minDpsvDOMElement.value != '' && maxDpsvDOMElement.value != '' && parseInt(maxDpsvDOMElement.value) <= parseInt(minDpsvDOMElement.value)) {
				document.getElementById('warning_mindpsv').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				document.getElementById('warning_maxdpsv').style = 'visibility:visible;';
				potentialConflicts.dpsv = 1;
			} else {
				document.getElementById('warning_mindpsv').style = 'visibility:hidden;';
				document.getElementById('warning_maxdpsv').style = 'visibility:hidden;';
				delete potentialConflicts.dpsv;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}

		}
	}

	// conflict: active client VL + permanently selected VL
	if (permanentVLDOMElement && activeClientVLDOMElement) {
		activeClientVLDOMElement.addEventListener('change', e => {
			if(e.target.checked && permanentVLDOMElement.value != ''){
				document.getElementById('warning_activevirtuallibrary').style = 'visibility:visible;';
				document.getElementById('warning_virtuallibrary').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				potentialConflicts.virtuallibs = 1;
			} else if (e.target.checked && req1DOMelement.value == 'virtuallibrary') {
				document.getElementById('warning_activevirtuallibrary').style = 'visibility:visible;';
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				potentialConflicts.vlibrequest1 = 1;
			} else {
				if (!("dupeuserrequests" in potentialConflicts) && !("lastplayedrequest1" in potentialConflicts) && !("yearrequest1" in potentialConflicts) && !("artistrequest1" in potentialConflicts) && !("genrerequest1" in potentialConflicts) && ((permanentVLDOMElement.value != '' && req1DOMelement.value != 'virtuallibrary') || (permanentVLDOMElement.value == '' && req1DOMelement.value == 'virtuallibrary'))) {
					document.getElementById('warning_request1fromuser').style = 'visibility:hidden;';
				}
				document.getElementById('warning_activevirtuallibrary').style = 'visibility:hidden;';
				if ((permanentVLDOMElement.value != '' && req1DOMelement.value != 'virtuallibrary') || (permanentVLDOMElement.value == '' && req1DOMelement.value == 'virtuallibrary')) {
					document.getElementById('warning_virtuallibrary').style = 'visibility:hidden;';
				}
				delete potentialConflicts.virtuallibs;
				delete potentialConflicts.vlibrequest1;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		});
		permanentVLDOMElement.addEventListener('change', changeHandler, false);
		function changeHandler() {
			if (permanentVLDOMElement.value != '' && activeClientVLDOMElement.checked) {
				document.getElementById('warning_activevirtuallibrary').style = 'visibility:visible;';
				document.getElementById('warning_virtuallibrary').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				potentialConflicts.virtuallibs = 1;
			} else if (permanentVLDOMElement.value != '' && req1DOMelement.value == 'virtuallibrary') {
				document.getElementById('warning_virtuallibrary').style = 'visibility:visible;';
				document.getElementById('warning_request1fromuser').style = 'visibility:visible;';
				warningmsgDOMElement.style = 'visibility:visible;';
				potentialConflicts.vlibrequest1 = 1;
			} else {
				if (!("dupeuserrequests" in potentialConflicts) && !("lastplayedrequest1" in potentialConflicts) && !("yearrequest1" in potentialConflicts) && !("artistrequest1" in potentialConflicts) && !("genrerequest1" in potentialConflicts) && ((!activeClientVLDOMElement.checked && req1DOMelement.value == 'virtuallibrary') || (activeClientVLDOMElement.checked && req1DOMelement.value != 'virtuallibrary'))) {
					document.getElementById('warning_request1fromuser').style = 'visibility:hidden;';
				}
				if ((!activeClientVLDOMElement.checked && req1DOMelement.value == 'virtuallibrary') || (activeClientVLDOMElement.checked && req1DOMelement.value != 'virtuallibrary')) {
					document.getElementById('warning_activevirtuallibrary').style = 'visibility:hidden;';
				}
				document.getElementById('warning_virtuallibrary').style = 'visibility:hidden;';
				delete potentialConflicts.virtuallibs;
				delete potentialConflicts.vlibrequest1;
				if (Object.keys(potentialConflicts).length == 0) {
					warningmsgDOMElement.style = 'visibility:hidden;';
				}
			}
		}
	}
});
</script>
