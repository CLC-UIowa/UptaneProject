# Uptane Electrum Model Documentation

Link to Uptane standards document: https://uptane.github.io/papers/uptane-standard.1.1.0.pdf.  
Link to Uptane deployment best practices: https://uptane.github.io/papers/V1.2.0_uptane_deploy.pdf.   

NOTE: This documentation may lag a little bit behind what is in the Electrum model; I will
update it ASAP.

## Signatures

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

## Relations

* Repository
  * var **out_primary**: set Metadata-- Both repositories can send metadata to the Primary ECU.Section 5.3.2.1 page 21: "The Director generates new metadata representing the desired set of images to be installed on the vehicle... It then sends this metadata to the Primary..." Section 5.3.1 page 19: "The Image repository SHALL expose an interface permitting the download of metadata..." So, out_primary stores the set of metadata that a repository wishes to send to the Primary ECU (whether this transfer of information is initiated by the ECU or by the Repository is not important for this model).
* ECU
  * var **current_metadata**: set Metadata-- For full and partial verification, each new metadata file of a certain role (Root, Targets, Snapshot, or Timestamp) is compared to the most recently downloaded version of that metadata. For example, section 5.4.4.4 page 32 says "Check that the version number of the previous Timestamp metadata file, if any, is less than or equal to the version number of this Timestamp metadata file." So, **current_metadata** refers to the most recently downloaded version, whereas **new_metadata** refers to the new metadata undergoing verification. 
  * var **new_metadata**: set Metadata-- see **current_metadata**
  * PrimaryECU
    * var **out_secondaries**: set Metadata-- Section 5.4.2.6 page 25: "The Primary SHALL send its latest downloaded metadata to all of its associated Secondaries." The standards document does not mandate that all metadata must be sent to all secondaries, just the minimum metadata needed for verification. However, the best practices document (page 43) says "it is RECOMMENDED that a Primary use a broadcast network, such as CAN, CAN FD, or Ethernet to transmit metadata to all of its Secondaries at the same time." Currently, the model assumes that the Primary broadcasts information to all secondaries. I am not sure if the model should allow for unicasting.
* Metadata: The standards document outlines components that should be present in all metadata files (section 5.2.1).
  * **signatures**: set Signature-- Section 5.2.1 page 14: All metadata should contain "An attribute containing the signature(s) of the payload." The signatures are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate).
  * **signature_count**: SignatureCount-- We need to be able to measure the cardinality of the **signatures** field (or more precisely, an abstraction of that cardinality) to make sure that the metadata reaches some arbitrary number of signatures. This is checked during full verification, for example: "Check that it (the metadata) has been signed by the threshold of keys specified in the latest Root metadata file" (section 5.4.4.4 page 32). There is a difference between signature count and key count, as there could be multiple (redundant) signatures with the same key. So, we must somehow constrain the signature_count field to correlate with the number of unique signing keys. Maybe this relation should just be called key_count instead.
  * **version**: Version-- Section 5.2.1 page 14: All metadata should contain "An integer version number, which SHOULD be incremented each time the metadata file is updated." The version numbers are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
  * **expiration**: MyTime-- Section 5.2.1 page 14: All metadata should contain "An expiration date and time." The expiration timestamps are checked during full verification (section 5.4.4.2, also see the **FullVerification** predicate). 
  * **role**: Role-- Section 5.2.1 page 14: All metadata should contain "An indicator of the type of role (Root, Targets, Snapshot, or Timestamp)." This relation is not strictly necessary (because we have an Alloy signature for each metadata type), but it is used for convenience in writing predicate preconditions and postconditions.
  * **hashes**: some Hash-- Various parts of full verification (5.4.4.2) involve cross-checking metadata hashes. For example, "Check that the non-custom metadata (i.e., length and hashes) of the unencrypted or encrypted image are the same in both sets of metadata" (page 30) and "Check the previously downloaded Snapshot metadata file from the Directory repository (if available). If the hashes and version number of that file match the hashes and version number listed in the new Timestamp metadata, there are no new updates and the verification process MAY be stopped and considered complete." Strictly speaking, we only need hashes for snapshot and targets metadata (as far as I can tell). But, it makes the most sense to me to include **hashes** as a general Metadata field, as it is needed by multiple types of Metadata and in theory, any type of Metadata can have one or more hashes.
  * **source**-- Metadata can be downloaded/sent from the Image and Director Repositories, and during Full Verification, it is necessary to know which repository each metadata file came from: E.g., "Verify that Targets metadata from the Director and Image repositories match" 
  (section 5.4.4.2, page 30).
  * RootMetadata
    * **key_mapping**: Role lone -> some MetadataKey-- Section 5.2.2 page 14: Root metadata should contain "A representation of the public keys for all four roles." The public keys are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
    * **signature_count_mapping**: Role -> one SignatureCount-- Section 5.2.2 page 14: Root metadata should contain "An attribute mapping each role to ... the threshold of signatures required for that role." Signature counts are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
  * TargetsMetadata
    * **image_hashes**: Image -> some Hash-- Section 5.2.3 page 14: "The Targets metadata on a repository contains all of the information about images to be installed on ECUs. This includes... hashes..." Hashes are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
    * **image_filesizes**: Image -> one FileSize-- Section 5.2.3 page 14: "The Targets metadata on a repository contains all of the information about images to be installed on ECUs. This includes... file sizes..." File sizes are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
    * **delegations**: lone DelegationsMetadata-- Section 5.2.3 page 15: "Targets metadata can also contain metadata about delegations, allowing one Targets role to delegate its authority to another." Delegations are checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
  * SnapshotMetadata
    * **targets_info**: TargetsMetadata -> one Version-- Section 5.2.4 page 17: "The filename and version number of the Targets metadata file." Filenames are aliases for files, so the TargetsMetadata Alloy signature is used rather than a Filename signature. Targets information is checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
  * TimestampMetadata
    * **latest_snapshot**: SnapshotMetadata -> Version-- Section 5.2.5, page 17: Timestamp metadata must contain "The ... version number of the latest Snapshot metadata on the repository." The version number of the latest Snapshot metadata is checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). 
    * **snapshot_hashes**: Hash -> one HashFunction-- Section 5.2.5, page 17: Timestamp metadata must contain "One or more hashes of the Snapshot metadata file, along with the hashing function used." The hashes of the latest Snapshot metadata is checked during Full Verification (section 5.4.4.2, also see the **FullVerification** predicate). Right now, I am unsure whether or not we need to keep track of hash functions.
* TimeServer
  * var **current_time**: MyTime-- Section 5.4 page 22: "ECUs MUST have a secure source of time. An OEM/Uptane implementer MAY use any external source of time that is demonstrably secure. The Uptane De- ployment Best Practices document ([DEPLOY]) describes one way to implement an external time server to cryptographically attest time, as well as the security properties required." This time is checked during full verification (section 5.4.4.2, also see the **FullVerification** predicate). I am not sure how much effort we should put into modeling the time server given that it is an implementation choice.
* Track
  * var **op**: lone Operator-- used to keep track of the operator just applied to the system.

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
  * **FullVerificationRoot**
  * **DoNothing**
  
## Predicates

* **SendMetadataToPrimary**: Section 5.3.2.1 page 21-- "The Director generates new metadata representing the desired set of images to be installed on the vehicle... It then sends this metadata to the Primary..."
  * **Preconditions**:
    * **The Director's out_primary field contains one Targets metadata File**-- Section 5.3.2.1 describes how the Director directs installation of images, and on page 21 it notes that the metadata generated "includes Targets (Section 5.2.3), Snapshot (Section 5.2.4), and Timestamp (Section 5.2.5) metadata. It then sends this metadata to the Primary as described in Section 5.4.2.3."
  	* **The Director's out_primary field contains one Snapshots metadata File**-- see previous 
    * **The Director's out_primary field contains one Timestamp metadata File**-- see previous
  * **Postconditions**:
    * **The Primary ECU receives the metadata in its new_metadata field.**-- Section 2.2 page 4 describes what the Primary ECU does: "A Primary ECU downloads and verifies update images and metadata for itself and for Secondary ECUs, and distributes images and metadata to Secondaries. Thus, it requires extra storage space and a means to download images and metadata." The Primary ECU needs space to store the new metadata (in our model, the **new_metadata** field) before it is verified (see **FullVerification**).
  * **Frame conditions**:
    * **Besides previously discussed postconditions, nothing else changes.**
* **SendMetadataToSecondaries**: Section 5.4.2.6 page 25-- "The Primary SHALL send its latest downloaded metadata to all of its associated Secondaries." The standards document does not mandate that all metadata must be sent to all secondaries, just the minimum metadata needed for verification. However, the best practices document (page 43) says "it is RECOMMENDED that a Primary use a broadcast network, such as CAN, CAN FD, or Ethernet to transmit metadata to all of its Secondaries at the same time."
  * **Preconditions**:
    * **The Director's out_primary field contains one Root metadata File**-- Section 5.4.2.6 says "The metadata it sends to each Secondary MUST include all of the metadata required for verification on that Secondary. For full verification Secondaries, this includes the metadata for all four roles from both repositories.. For partial verification Secondaries, this MAY include... at a minimum, ... only the Targets metadata file from the Director repository." As described in **SendMetadataToSecondaries**, this model assumes metadata broadcasting, where all metadata is broadcasted to all secondaries. This means that the latest copies of Root, Targets, Snapshot, and Timestamp should all be present.
    * **The Director's out_primary field contains one Targets metadata File**-- see previous
    * **The Director's out_primary field contains one Snapshot metadata File**-- see previous
    * **The Director's out_primary field contains one Timestamp metadata File**-- see previous
  * **Postconditions**:
    * **The Secondary ECUs receive the metadata in their new_metadata fields.**-- Like Primary ECUs, Secondary ECUs need to inspect new metadata during full verification (see **FullVerification**). Section 2.2 page 4: "Secondary ECUs receive their update images and metadata from the Primary, and only need to verify and install their own metadata and images."
  * **Frame conditions**:
    * **Besides previously discussed postconditions, nothing else changes.**
* **FullVerificationRoot**: This predicate involves verifying root metadata as part of full verification (described in section 5.4.4.3).
  * **Preconditions**:
    * **The root metadata must reach a threshold signature count from valid keys for both current and new root metadata.**-- Section 5.4.4.3 page 31: "Version N+1 of the Root metadata file MUST have been signed by the following: (1) a threshold of keys specified in the latest Root metadata file (version N), and (2) a threshold of keys specified in the new Root metadata file being validated (version N+1)."
    * **The root metadata should not be an older version than the current root metadata.**-- Section 5.4.4.3 page 31: "The version number of the latest Root metadata file (version N) must be less than or equal to the version number of the new Root metadata file (version N+1)."
    * **The root metadata cannot have an expiration timestamp that is before the current time.**-- Section 5.4.4.3 page 31: "Check that the current (or latest securely attested) time is lower than the expiration timestamp in the latest Root metadata file."
  * **Postconditions**:
    * **The ECU updates to the latest version of root metadata.**-- Section 5.4.4.3 page 31: "Set the latest Root metadata file to the new Root metadata file."
    * **If Snapshot or Timestamp keys have been rotated, those metadata files are deleted.**-- Section 5.4.4.3 page 31: "If the Timestamp and/or Snapshot keys have been rotated, delete the previous Timestamp and Snapshot metadata files."
  * **Frame Conditions**:
    * **Besides previously discussed postconditions, nothing else changes.**
* **FullVerification**: Described in section 5.4.4.2, page 29. Also, section 5.4.4, page 28 says "A Primary ECU MUST perform full verification of metadata. A Secondary ECU SHOULD perform full verification of metadata."
  * **Preconditions**:
    * **The Primary ECU's new_metadata field contains one Timestamp metadata File**-- Section 5.4.4.4 page 32 instructs the ECU to "Download up to Y number of bytes" of Targets metadata, implying that there should be a new Targets metadata file for full verification. This new metadata's fields (including signatures, version number, etc.) are checked during full verification, so the metadata file must be present.
    * **The Primary ECU's new_metadata field contains one Snapshot metadata File**-- see previous, but check section 5.4.4.5.
    * **The Primary ECU's new_metadata field contains one Targets metadata File**-- see previous, but check section 5.4.4.6.
    * **The hashes and version of the current Snapshot metadata do not match those specified in the new Timestamp metadata. This ensures that a new update is available.**-- Section 5.4.4.2 page 29-- "Check the previously downloaded Snapshot metadata file from the Directory repository (if available). If the hashes and version number of that file match the hashes and version number listed in the new Timestamp metadata, there are no new updates and the verification process MAY be stopped and considered complete. 
    * **The new Targets metadata should contain a positive number of image hashes.**-- Section 5.4.4.2, page 30: "If the Targets metadata from the Directory repository indicates that there are no new targets that are not already currently installed, the verification process MAY be stopped and considered complete." Targets metadata stores hashes and file sizes of images to be installed, so we check to make sure some hashes exist to make sure there are in fact new images.
    * **The new Snapshots metadata should not reference Targets metadata with an older version number.**-- Section 5.4.4.5, page 32: "Check that the version number listed by the previous Snapshot metadata file for each Targets metadata file is less than or equal to its version number in this Snapshot metadata file."
    * **All new metadata should not be an older version than the current metadata for the corresponding role.**-- Section 5.4.4.4 page 32: "Check that the version number of the previous Timestamp metadata file, if any, is less than or equal to the version number of this Timestamp metadata file." This check is done for all types of metadata, not just Timestamp.
    * **The Targets metadata version number should match the version number specified in the current Snapshot metadata.**-- Section 5.4.4.6, page 33: "The version number of the new Targets metadata file MUST match the version number listed in the latest Snapshot metadata."
    * **Each metadata must reach a threshold signature count from valid keys.**-- Section 5.4.4.4 page 32: "Check that it has been signed by the threshold of keys specified in the latest Root metadata file." This check is done for all types of metadata, not just Timestamp.
    * **Metadata cannot have an expiration timestamp that is before the current time.**-- Section 5.4.4.4 page 32: "Check that the current (or latest securely attested) time is lower than the expiration timestamp in this Timestamp metadata file." This check is done for all types of metadata, not just Timestamp.
  * **Postconditions**:
    * **The ECU's current_metadata field is updated to the new metadata.**--  Each ECU "downloads and verifies the latest metadata" (section 2.2 page 4), where verification involves checking the new metadata with the current/previous metadata file (e.g., looking at the "version number of the previous Timestamp metadata file," section 5.4.4.4 page 32). After verification is complete, the next time the ECU attempts to do verification, it will need to look back at the metadata we've just verified. So, in this model, we store it in the **current_metadata** field so it is not overwritten when new metadata comes in.
  * **Frame conditions**:
    * **Besides previously discussed postconditions, nothing else changes.**
* **DoNothing**: Does nothing. Allows the system to loop on the final state.
* **Init**: Currently, no initial state conditions are set.
* **Trans**: There must be an operator applied between each pair of states.
  
## Facts

* **Scheduler**: Enforces initial state conditions and makes sure a single operator holds at each time step.
* Soon, I will convert a good number of the model's facts into assertions.


## Questions
* Does the sending of metadata from the Director to the Primary ECU happen all at once, in batch? Or does the metadata get sent file by file as the ECU undergoes verification? Compare the "directing installation" section to the "full verification" section.
* In the Uptane standard, there is a lot of flexibility for secondary ECUs (from full verification to checking just a single metadata file). Should the model be this flexible?  
* How course-grained should the FullVerification predicate be? The Uptane standard says that if a step of verification fails, then the process is terminated and an error code is returned-- but in this model, verification only happens if preconditions are fulfilled.
