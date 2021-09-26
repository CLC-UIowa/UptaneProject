# Uptane Electrum Model Documentation

Link to Uptane standards document: https://uptane.github.io/papers/uptane-standard.1.1.0.pdf.
Link to Uptane deployment best practices: https://uptane.github.io/papers/V1.2.0_uptane_deploy.pdf.   

## Signatures and Relations

* **Repository** (abstract): Section 5 page 11-- "At a high level, Uptane requires: Two software repositories: An Image repository... A Director repository..."
  * **DirectorRepo** (one): see **Repository**
  * **ImageRepo** (one): See **Repository**
* **ECU** (abstract): Section 2.2 page 4-- "ECUs: Terms used to describe the control units within a ground vehicle."
  * **PrimaryECU** (one): Section 2.2 page 4-- "A Primary ECU downloads and verifies update images and metadata for itself and for Secondary ECUs, and distributes images and metadata to Secondaries."
  * **SecondaryECU**: Section 2.2 page 4-- "Secondary ECUs receive their update images and metadata from the Primary, and only need to verify and install their own metadata and images."
* **ID** (abstract): Various IDs are used to uniquely identify entities. In general, I'm still not sure whether these IDs are necessary for modeling because they might just be aliases for the entities themselves.
  * **VehicleID**: Stored in the vehicle version manifest (section 5.4.2.1.1 page 24). 
  * **ECUId**: Used by Targets metadata to map software images to ECUs (section 5.2.3.1.1 page 16).
  * **KeyID**: Section 5.2.1 page 13-- "Every public key MUST be represented using a public key identifier." This ID is stored in metadata (section 5.2.1 page 14).
* **ECUVersionReport**: Section 5.4.2.1.2 page 24-- "An ECU version report is a metadata structure that MUST contain the following information..."
* **VehicleVersionManifest**: Section 2.2 page 4-- "Vehicle Version Manifest: A compilation of all ECU version reports on a vehicle. It serves as a master list of all images currently running on all ECUs in the vehicle." The Director uses vehicle version manifests in determining which images should be installed on which ECUs (section 5.3.2.1).
* **InventoryDatabaseEntry**: Section 5.3.2 page 20-- the Director "consults a private inventory database containing information on vehicles, ECUs, and software revisions."
* **Image**: Section 2.2 page 3-- "Image: File containing software for an ECU to install."
* **Key**: Keys are needed to make signatures (see **Signature**). Section 5 page 11-- Uptane involves "A public key infrastructure supporting the required metadata production
and signing roles on each repository."
* **HashFunction**: Used in Timestamp metadata (section 5.2.5 page 17), vehicle version manifests (section 5.4.2.1.1 page 24), ECU version reports (section 5.4.2.1.2 page 24). I'm still not 100% if hashes are needed for our purposes-- just having the hash might suffice. I think the specific hash functions used might just be implementation details.
* **Hash**: See **HashFunction**. Also, image hashes are stored by Targets metadata (section 5.2.3 page 14). Hashes are checked during full verification.
* **Signature**: Images, metadata files, and vehicle version manifests are digitally signed (section 3.2.2.2 page 7, section 5.2.1 page 14, section 5.4.2.1.1 page 24).
* **SignatureCount** (ordered): Signature counts are only needed for comparison (>, <, or =) (see **Full Verification**).
* **FileSize** (ordered): Image and targets metadata is required to keep track of image file size (section 5.2.3.1.1 page 15; section 5.2.3 page 14).
* **Version** (ordered): Section 5.2.1 page 14 describes components present in all metadata file, including "An integer version number, which SHOULD be incremented each time the metadata file is updated." This version number is only used for comparison (<, >, or =) (see **Full Verification**), so full integer functionality is not needed.
* **Metadata** (abstract): Section 5.2 page 13-- "Uptane’s security guarantees all rely on properly created metadata that follows a designated structure."
  * **RootMetadata**: Section 5.2.2 page 14 
  * **TargetsMetadata**: Section 5.2.3 page 14 
  * **SnapshotMetadata**: Section 5.2.4 page 17 
  * **TimestampMetadata**: Section 5.2.5 page 17 
  * **DelegationsMetadata**: Section 5.2.3.2 page 16 
* **Delegation**: Section 5.3.1 page 19-- "The Image repository SHALL provide a method for authorized users to upload images and their associated metadata. It SHALL check that a user writing metadata and images is authorized to do so for that specific image by checking the chain of delegations" 
* **TimeServer** (one): Section 5.4 page 22-- "ECUs MUST have a secure source of time. An OEM/Uptane implementer MAY use any external source of time that is demonstrably secure. The Uptane Deployment Best Practices document ([DEPLOY]) describes one way to implement an external time server to cryptographically attest time, as well as the security properties required."
* **MyTime** (ordered): Represents a general notion of time.
* **Track** (one): For modeling operators in Electrum

## Enums

* **VerificationType**: Section 5.4.4 page 28-- "A Primary ECU MUST perform full verification of metadata. A Secondary ECU SHOULD perform full verification of metadata. If a Secondary cannot perform full verification, it SHALL, at the very least, perform partial verification."
  * **Full**: Section 5.4.4.2 page 29
  * **Partial**: Section 5.4.4.1 page 28
* **Role**: Section 5.1 page 12-- "Each role has a particular type of metadata associated with it..."
  * **Root**: Section 5.1.1 page 12
  * **Timestamp**: Section 5.1.4 page 13
  * **Snapshot**: Section 5.1.3 page 13
  * **Targets**: Section 5.1.2 page 12
* **Operator**: For documentation of the operators, see the Predicates section 
  * **SendMetadataToPrimary**
  * **SendMetadataToSecondaries**
  * **FullVerification**
  * **DoNothing**
  
## Predicates

* **SendMetadataToPrimary**: Section 5.3.2.1 page 21-- "The Director generates new metadata representing the desired set of images to be installed on the vehicle... It then sends this metadata to the Primary..."
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **SendMetadataToSecondaries**: Section 5.4.2.6 page 25-- "The Primary SHALL send its latest downloaded metadata to all of its associated Secondaries." The standards document does not mandate that all metadata must be sent to all secondaries, just the minimum metadata needed for verification. However, the best practices document (page 43) says "it is RECOMMENDED that a Primary use a broadcast network, such as CAN, CAN FD, or Ethernet to transmit metadata to all of its Secondaries at the same time."
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **FullVerification**: Described in section 5.4.4.2, page 29. Also, section 5.4.4, page 28 says "A Primary ECU MUST perform full verification of metadata. A Secondary ECU SHOULD perform full verification of metadata."
  * **Preconditions**:
  * **Postconditions**:
  * **Frame conditions**:
* **DoNothing**: Does nothing. Allows the system to loop on the final state.
* **Init**: Currently, no initial state conditions are set.
* **Trans**: There must be an operator applied between each pair of states.
  
## Facts

* **Scheduler**: Enforces initial state conditions and makes sure a single operator holds at each time step.
* Soon, I will convert a good number of the model's facts into assertions.
