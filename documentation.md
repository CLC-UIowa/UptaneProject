# Uptane Electrum Model Documentation

Link to Uptane standards document: https://uptane.github.io/papers/uptane-standard.1.1.0.pdf.
Link to Uptane deployment best practices: https://uptane.github.io/papers/V1.2.0_uptane_deploy.pdf.   

## Signatures and Relations

* **Repository** (abstract): Standards document section 5 page 11-- "At a high level, Uptane requires: Two software repositories: An Image repository... A Director repository..."
  * **DirectorRepo** (one): see Repository
  * **ImageRepo** (one): See Repository
* **ECU** (abstract)
  * **PrimaryECU** (one)
  * **SecondaryECU**
* **ID** (abstract)
  * **VehicleID**
  * **ECUId**
  * **KeyID**
* **ECUVersionReport**
* **VehicleVersionManifest**
* **InventoryDatabaseEntry**
* **Image**
* **Key**
* **Hash**
* **HashFunction**
* **Signature**
* **SignatureCount**
* **FileSize**
* **Version**
* **Metadata** (abstract): Standards document page 13 section 5.2-- "Uptane’s security guarantees all rely on properly created metadata that follows a designated structure."
  * **RootMetadata**: Standards document page 14 section 5.2.2
  * **TargetsMetadata**: Standards document page 14 section 5.2.3
  * **SnapshotMetadata**: Standards document page 17 section 5.2.4
  * **TimestampMetadata**: Standards document page 17 section 5.2.5
  * **DelegationsMetadata**: Standards document page 16 section 5.2.3.2
* **Delegation**
* **MyTime**
* **TimeServer** (one)
* **Track** (one): For modeling operators in Electrum

## Enums

* **VerificationType**: Full, Partial
* **Role**: Root, Timestamp, Snapshot, Targets
* **Operator**:  SendMetadataToPrimary, SendMetadataToSecondaries, FullVerification, Nothing
  
## Predicates

* **SendMetadataToPrimary**
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **SendMetadataToSecondaries**: Standards document section 5.4.2.6 page 25-- "The Primary SHALL send its latest downloaded metadata to all of its associated Secondaries." The standards document does not mandate that all metadata must be sent to all secondaries, just the minimum metadata needed for verification. However, the best practices document (page 43) says "it is RECOMMENDED that a Primary use a broadcast network, such as CAN, CAN FD, or Ethernet to transmit metadata to all of its Secondaries at the same time."
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **FullVerification**: Described in section 5.4.4.2, page 29 of the standards document. Also, section 5.4.4, page 28 of the standards document says "A Primary ECU MUST perform full verification of metadata. A Secondary ECU SHOULD perform full verification of metadata."
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **DoNothing**: Does nothing. Allows the system to loop on the final state.
* **Init**: Currently, no initial state conditions are set.
* **Trans**: There must be an operator applied between each pair of states.
  
## Facts

* **Scheduler**: Enforces initial state conditions and makes sure a single operator holds at each time step.
