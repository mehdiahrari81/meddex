# FHIR interoperability

The current adapter targets FHIR R4-shaped JSON without claiming conformance to a national profile. Internal domain models remain primary.

Stable medication identity can map to `Medication` with sourced codes/text/ingredients where available. A clinician-originated order requires verified prescriber/order metadata not currently collected. A patient-confirmed prescription-derived record maps conservatively to `MedicationStatement`; a manually created reminder cannot become `MedicationRequest`. Schedule/reminder and dose log are application adherence data, not clinician orders.

Tests enforce that user-created reminders throw when order conversion is requested. Future exchange must select an explicit FHIR version/profile, validate resources against that profile, preserve source/provenance extensions, and obtain consent/authentication before transmission.
