open util/ordering[Version]
open util/ordering[SignatureCount]
open util/ordering[FileSize]
open util/ordering[MyTime]


-- Notes
-- * Manually using MyTime and TimeServer sigs
-- * Distinction between sending and downloading metadata
-- * When should new_metadata field be updated-- all at once or one at a time?
-- * TODO: Make Track just a diagnostic tool (move some relations out)
-- * TODO: Should we keep old metadata files for if stuff gets deleted?
-- * TODO: Partial verification
-- * TODO: Vehicle version manifests (?) Maybe we can assume the repos know which images/metadata to send
-- * TODO: Targets metadata delegations and custom info
-- * TODO: NoChangeExcept Primary AND secondary ECUs

-- * TODO: Image verification
-- * TODO: Check current_metadata for each repo type
-- * TODO: Option of having prior metadata not exist
-- * TODO: Initial state conditions
-- * TODO: Revisit snapshot full verification
-- * TODO: Keep track of previous metadata
-- * TODO: Split up SendMetadataToPrimary
-- * TODO: Update frame conditions (cmd F for "var")

/*
This week:

Image verification
Moving stuff out of Track
Investigating reference implementation
Slides
Added option of prior metadata not existing
*/




-------------------------
--- Components/actors ---
-------------------------
abstract sig Repository {
	var out_primary: set Metadata,
}
one sig DirectorRepo extends Repository {
	inventory_database: InventoryDatabase,
	var vehicle_version_manifests: set VehicleVersionManifest,
}
one sig InventoryDatabase {
	ecus: set ECU,
	-- other stuff
}
one sig ImageRepo extends Repository  {
	--database: set Image,
	--var out_primary: set Metadata,
}
sig HardwareID {}
abstract sig ECU {
	--key: ECUKey,
	var current_metadata: set Metadata,
	var new_metadata: set Metadata,
	var current_image: Image,
	var new_image: Image,
	var status: Status, 
	var version_report: ECUVersionReport,
	hardware_id: HardwareID,
}
one sig PrimaryECU extends ECU {
	var out_secondaries: set Metadata,
	var vehicle_version_manifest: VehicleVersionManifest,
	var all_version_reports: set ECUVersionReport,
	--verification: VerificationType,
    -- repo mapping file
}
some sig SecondaryECU extends ECU  {}
enum VerificationType { Full, Partial }

-----------
--- IDs ---
-----------
abstract sig ID {}
sig VehicleID, ECUId extends ID {}
sig KeyID extends ID {}


--- Vehicle and ECU Data ---
sig ECUVersionReport {
	signatures: set Signature,
	id: ECUId,
	image_file: Image,
	image_hash: Hash, 
	version: Version,
	latest_time: MyTime,
}
sig VehicleVersionManifest {
	signatures: set Signature,
	vehicle_id: VehicleID,
	ecu_id: ECUId,
	version_reports: set ECUVersionReport,
}
sig InventoryDatabaseEntry {
	--vehicle_id: VehicleID,
	--ecus: ECUId -> VehicleID -> ECUKey -> KeyID, -- Arity 5 issue
}

-------------
--- Files ---
-------------
--sig Filename {}
sig Image {
	i_hashes: some Hash,
}

----------------------
--- Authentication ---
----------------------
sig Key {}
sig ECUKey, MetadataKey extends Key {} -- This distinction might not be necessary, could just use Key
sig Hash {}
sig HashFunction {}
sig Signature {
	key: Key,
}
sig SignatureCount {}

----------------
--- Metadata ---
----------------
sig FileSize {}
sig Version {}
enum Role { Root, Timestamp, Snapshot, Targets }
abstract sig Metadata {
	signatures: set Signature,
	signature_count: SignatureCount,
	version: Version,
	expiration: MyTime,
	role: Role,
	hashes: some Hash,
	source: Repository,
}
sig RootMetadata extends Metadata {
	-- public_keys: set Key,
	key_mapping: Role lone -> some MetadataKey,
	signature_count_mapping: Role -> one SignatureCount
	-- can add additional fields for delegations roles if necessary
}
sig ReleaseCounter {}
sig TargetsMetadata extends Metadata {
	image_hashes: Image -> some Hash,
	image_filesizes: Image -> one FileSize,
	delegations: lone DelegationsMetadata,
	custom_metadata: Image -> CustomMetadata
}
sig CustomMetadata {
	ecu_id: ECU,
	hardware_ids: some HardwareID,
	release_count: Version,
}
sig SnapshotMetadata extends Metadata {
	targets_info: TargetsMetadata -> one Version, -- maybe lone?
	-- optional root filename and version number
}
sig TimestampMetadata extends Metadata {
	latest_snapshot: SnapshotMetadata -> Version,
	snapshot_hashes: Hash -> one HashFunction,
}

/*
sig DelegationsRole {
	--keys: set Key,
	--threshold: SignatureCount,
}
enum Terminating { Termination, NotTerminating }
*/
sig Delegation {
	--images: set Image,
	-- hardware identifiers,
	--roles: set DelegationsRole
	
}
sig DelegationsMetadata extends Metadata {
	--public_keys: set Key,
	--delegations: set Delegation
}

-------------------
--- Time server ---
-------------------
sig MyTime {}
one sig TimeServer {
var current_time: MyTime
}

------------------
--- Operations ---
------------------
enum Operator { SendMetadataToPrimary, SendMetadataToSecondaries, 
                FullVerification, FullVerificationTargetsMatch,
                FullVerificationRoot, FullVerificationTargets, 
                FullVerificationTimestamp, FullVerificationSnapshot,
			         	VerifyImage, SendVehicleVersionManifest, SendECUVersionReport,
                DoNothing }
enum Status { Abort, Success }

one sig Track { 
	var op: lone Operator,
	var verification_repo: lone Repository, -- NOTE: Move to ECU
}

pred TrackFrameConditions[] {
	Track.verification_repo' = Track.verification_repo
}

/*
pred NoChangeExceptDirector[r: DirectorRepo -> univ, D: set DirectorRepo] {
	all d: DirectorRepo - D | d.r' = d.r
}
*/

pred NoChangeExceptRepo[r: Repository -> univ, R: set Repository] {
	all rep: Repository - R | rep.r' = rep.r
}

/*
pred NoChangeExceptPrimary[r: PrimaryECU -> univ, P: set PrimaryECU] {
	all p: PrimaryECU - P | p.r' = p.r
}
*/

pred NoChangeExceptECU[r: ECU -> univ, E: set ECU] {
	all e: ECU - E | e.r' = e.r
}

pred SendMetadataToPrimary[r: Repository, p: PrimaryECU] {
	-- NOTE-- should this be in batch? or one metadata file at a time?
	--- Preconditions ---
	-- The director sends a full set of metadata
	--one (r.out_primary & TargetsMetadata) 
	--one (r.out_primary & SnapshotMetadata) 
	--one (r.out_primary & TimestampMetadata)
								  

	--- Postconditions ---
	-- Update out_primary field of Director
	no r.out_primary'
	-- Update new_metadata field of primary ECU
	p.new_metadata' = r.out_primary
	Track.op' = SendMetadataToPrimary

	--- Frame conditions ---
	NoChangeExceptRepo[out_primary, r]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, p]	
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	TrackFrameConditions[]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred SendMetadataToSecondaries[p: PrimaryECU, S: set SecondaryECU] {
	--- Preconditions ---
	-- The primary must be broadcasting to all secondaries (?)
	#(p.out_secondaries) = 4 
    one (p.out_secondaries & RootMetadata) 
	one (p.out_secondaries & TargetsMetadata) 
	one (p.out_secondaries & SnapshotMetadata) 
	one (p.out_secondaries & TimestampMetadata)
	
	--- Postconditions ---
	-- Update out_secondaries field of the Primary
	no p.out_secondaries'
	-- Update new_metadata field of secondary ECUs
	all s: S | s.new_metadata' = p.out_secondaries
	Track.op' = SendMetadataToSecondaries

	--- Frame conditions ---
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[status, none]
	NoChangeExceptECU[out_secondaries, p]
	TrackFrameConditions[]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred FullVerificationPreconditions[p: PrimaryECU, m1: lone Metadata, m2: Metadata, root: RootMetadata] {
	-- New metadata is not older version
	(
		no m1 or
		lte[ 
			m1.version, 
	    	m2.version 
	  	] 
	)

	-- Check signature count (compare to threshold)
	gte[
		m2.signature_count, 
        (root.signature_count_mapping)[m2.role]
	]

	-- Check validity of signatures
	all s: m2.signatures |
		s.key in root.key_mapping[m2.role]

	-- Note-- same key doing multiple signatures?

	-- Metadata cannot be expired
	lt[
		TimeServer.current_time, 
		m2.expiration
	]
}

pred FullVerificationTargetsMatch[p: PrimaryECU] {
	---------------------
	--- Preconditions ---
	---------------------
	Track.op = FullVerificationTargets
	p.status = Success
	Track.verification_repo = ImageRepo
	

	----------------------
	--- Postconditions ---
	----------------------
	(
		// Image hashes and filesizes of both targets metadata files need to match
		((p.new_metadata & TargetsMetadata) & (source.DirectorRepo)).image_hashes = 
		((p.new_metadata & TargetsMetadata) & (source.ImageRepo)).image_hashes 
		
		and
		
		((p.new_metadata & TargetsMetadata) & (source.DirectorRepo)).image_filesizes = 
		((p.new_metadata & TargetsMetadata) & (source.ImageRepo)).image_filesizes 
	)
	implies
	p.status' = Success
	else
	p.status' = Abort
	

	Track.op' = FullVerificationTargetsMatch
	Track.verification_repo' = none
	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
  NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
} 

pred FullVerificationTargets[p: PrimaryECU, t: TargetsMetadata] {
	---------------------
	--- Preconditions ---
	---------------------
	Track.op = FullVerificationSnapshot
	p.status = Success

	-- Source repo matches
	Track.verification_repo = DirectorRepo implies t.source = DirectorRepo
	Track.verification_repo = ImageRepo    implies t.source = ImageRepo

	-- s is in the new_metadata field
	t in p.new_metadata

	----------------------
	--- Postconditions ---
	----------------------
	(
		FullVerificationPreconditions[p, 
                                 	 (p.current_metadata & TargetsMetadata),
                                 	  t,
								 	 (p.current_metadata & RootMetadata)]

		and

		-- Make sure there are targets
		some t.image_hashes

		and

		-- Target metadata version number should match the version number
		-- listed in snapshot metadata
		let t = (p.new_metadata & TargetsMetadata) |
			t.version = (p.current_metadata & SnapshotMetadata).targets_info[t]
	)
	implies
	p.status' = Success
	else
	p.status' = Abort

	Track.verification_repo = DirectorRepo implies Track.verification_repo' = DirectorRepo
	Track.verification_repo = ImageRepo    implies Track.verification_repo' = ImageRepo

	Track.op' = FullVerificationTargets


	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata,none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred FullVerificationTimestamp[p: PrimaryECU, t: TimestampMetadata] {
	---------------------
	--- Preconditions ---
	---------------------
	Track.op = FullVerificationRoot
	p.status = Success

	-- Source repo matches
	Track.verification_repo = DirectorRepo implies t.source = DirectorRepo
	Track.verification_repo = ImageRepo    implies t.source = ImageRepo

	-- s is in the new_metadata field
	t in p.new_metadata

	----------------------
	--- Postconditions ---
	----------------------
	(
		FullVerificationPreconditions[p, 
                               	     (p.current_metadata & TimestampMetadata),
                              	     t,
									 (p.current_metadata & RootMetadata)]
	)
	implies
	p.status' = Success
	else
	p.status' = Abort

	Track.verification_repo = DirectorRepo implies Track.verification_repo' = DirectorRepo
	Track.verification_repo = ImageRepo    implies Track.verification_repo' = ImageRepo

	Track.op' = FullVerificationTimestamp

	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata,none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred FullVerificationSnapshot[p: PrimaryECU, s: SnapshotMetadata] {
	-- COME BACK TO THIS
	---------------------
	--- Preconditions ---
	---------------------
	Track.op = FullVerificationTimestamp
	p.status = Success

	-- Source repo matches
	Track.verification_repo = DirectorRepo implies s.source = DirectorRepo
	Track.verification_repo = ImageRepo    implies s.source = ImageRepo

	-- s is in the new_metadata field
	s in p.new_metadata

	----------------------
	--- Postconditions ---
	----------------------
	(
		FullVerificationPreconditions[p, 
	                                 (p.current_metadata & SnapshotMetadata),
	                                 s,
									 (p.current_metadata & RootMetadata)]

		and
	
		-- Compare current snapshot metadata hashes and version to 
		-- hashes and version in new timestamp (make sure there's a 
		-- new update) (FV4)
		(no (p.current_metadata & SnapshotMetadata) 

		or

	   ((p.current_metadata & SnapshotMetadata).hashes != 
		(p.new_metadata & TimestampMetadata).snapshot_hashes.HashFunction
		||
		(p.current_metadata & SnapshotMetadata).version != 
		(p.new_metadata & TimestampMetadata).latest_snapshot[SnapshotMetadata]))

		and
	
		-- Hashes and version number match timestamp (2)
		s.version = (p.current_metadata & TimestampMetadata).latest_snapshot[SnapshotMetadata] and
		s.hashes = (p.current_metadata & TimestampMetadata).snapshot_hashes.HashFunction

		and

		-- Make sure version numbers of targets in the snapshots metadata do not decrease (5 + 6)
		all t: (p.current_metadata & SnapshotMetadata).targets_info.Version |
			lte[
				(p.current_metadata & SnapshotMetadata).targets_info[t],
				s.targets_info[t]
			]	
	)
	implies
	p.status' = Success
	else
	p.status' = Abort

	Track.verification_repo = DirectorRepo implies Track.verification_repo' = DirectorRepo
	Track.verification_repo = ImageRepo    implies Track.verification_repo' = ImageRepo

	Track.op' = FullVerificationSnapshot

	------------------------
	--- Frame Conditions ---
	------------------------

	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata,none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred FullVerificationRoot[p: PrimaryECU, r: RootMetadata] {
	-- If there is no new root metadata, that is OK


	---------------------
	--- Preconditions ---
	---------------------
	-- Impose the correct order of steps in FullVerification
	Track.verification_repo = none or 
	(Track.op = FullVerificationTargets and p.status = Success and Track.verification_repo = DirectorRepo)

	-- Source repo matches
	Track.verification_repo = none         implies r.source = DirectorRepo
	Track.verification_repo = DirectorRepo implies r.source = ImageRepo

	-- r is in the new_metadata field
	r in p.new_metadata

	-- What is r's source if initially on ECU? Do we care?
		

	----------------------
	--- Postconditions ---
	----------------------
		(
			FullVerificationPreconditions[p, 
		                                 (p.current_metadata & RootMetadata),
		                                 r,
										 (p.current_metadata & RootMetadata)]
	
			and
	
			-- Check signature count with current and new root metadata (compare to threshold)
			gte[
				r.signature_count, 
		       ((p.current_metadata & RootMetadata).signature_count_mapping)[Root]
			]
		
			and
			
			gte[
				r.signature_count, 
		       ((p.new_metadata & RootMetadata).signature_count_mapping)[Root]
			]
		
			and
	
			-- Check validity of signatures with current and new root metadata
			all s: r.signatures |
				s.key in (p.current_metadata & RootMetadata).key_mapping[Root]
		
			and
	
			all s: r.signatures |
				s.key in (p.new_metadata & RootMetadata).key_mapping[Root]
		
		)
		implies
		p.status' = Success
		else
		p.status' = Abort
	


		r.source = DirectorRepo implies Track.verification_repo' = DirectorRepo 
		r.source = ImageRepo    implies Track.verification_repo' = ImageRepo


		
		-- Update to the latest version of Root metadata
		(p.current_metadata' & RootMetadata) = r 
	
		-- If Timestamp or Snapshot keys have been rotated, delete those metadata files
	   ((r.key_mapping[Timestamp] !=
		(p.current_metadata & RootMetadata).key_mapping[Timestamp])) implies
		(p.current_metadata' & TimestampMetadata) = none


	
	   ((r.key_mapping[Snapshot] !=
		(p.current_metadata & RootMetadata).key_mapping[Snapshot])) implies
		(p.current_metadata' & SnapshotMetadata) = none
	


		Track.op' = FullVerificationRoot


	------------------------
	--- Frame Conditions ---
	------------------------

	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata,p]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred FullVerification[p: PrimaryECU] {
	-- Note 1: We need to have metadata from the director AND image repos (maybe take in repo as argument).
	-- Note 2: Need to deal with delegations. 
	-- Note 3: Targets metadata ECU information? See "custom metadata about images"
	-- Note 4: Should be able to take SecondaryECU as input
	-- Note 5: Need to be able to handle cases where current metadata does not exist
	
	/*
	1. Root Director
	2. Timestamp Director
	3. Snapshot Director
	4. Targets Director
	5. Root Image
	6. Timestamp Image
	7. Snapshot Image
	8. Targets Image
	9. Targets Crossreference (Director and Image)
	*/

	---------------------
	--- Preconditions ---
	---------------------
	Track.op = FullVerificationTargetsMatch
	p.status = Success

	----------------------
	--- Postconditions ---
	----------------------
	p.current_metadata' = p.new_metadata
	Track.op' = FullVerification
	Track.verification_repo' = none
	
	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, p]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred PartialVerification[s: SecondaryECU] {
	DoNothing[]
}

pred VerifyImage[e: ECU, i: Image, t: TargetsMetadata] {
	---------------------
	--- Preconditions ---
	---------------------
	-- i is the new image on e
	e.new_image = i
	
	-- t is the latest targets metadata file from the Director repo
	t in ((e.current_metadata & TargetsMetadata) & source.DirectorRepo)

	-- Find the Targets metadata associated with this ECU identifier
    -- and check that the hardware identifier in the metadata matches 
    -- the ECU’s hardware identifier.
	one c: t.custom_metadata[Image] | c.ecu_id = e
	all c: t.custom_metadata[Image] | c.ecu_id = e implies e.hardware_id in c.hardware_ids

	-- Check that the release counter of the image in the previous metadata, 
    -- if it exists, is less than or equal to the release counter in the latest metadata.

	-- Check that hashes in the image match hashes in targets metadata
	t.image_hashes[i] = i.i_hashes


	----------------------
	--- Postconditions ---
	----------------------
	e.current_image' = e.new_image

	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred SendVehicleVersionManifest[p: PrimaryECU] {
	---------------------
	--- Preconditions ---
	---------------------
	-- none for now

	----------------------
	--- Postconditions ---
	----------------------
	p.vehicle_version_manifest in DirectorRepo.vehicle_version_manifests'

	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, DirectorRepo]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, none]
}

pred SendECUVersionReport[s: SecondaryECU] {
	---------------------
	--- Preconditions ---
	---------------------
	-- none for now

	----------------------
	--- Postconditions ---
	----------------------
	s.version_report in PrimaryECU.all_version_reports'

	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptRepo[out_primary, none]
	NoChangeExceptRepo[vehicle_version_manifests, none]
	NoChangeExceptECU[current_metadata, none]
	NoChangeExceptECU[new_metadata, none]
	NoChangeExceptECU[out_secondaries, none]
	NoChangeExceptECU[current_image, none]
	NoChangeExceptECU[new_image, none]
	NoChangeExceptECU[version_report, none]
	NoChangeExceptECU[vehicle_version_manifest, none]
	NoChangeExceptECU[all_version_reports, PrimaryECU]
}

pred DoNothing[] {
	-- Repo
	out_primary' = out_primary
	vehicle_version_manifests' = vehicle_version_manifests
	
	-- ECU
	current_metadata' = current_metadata
	new_metadata' = new_metadata
	current_image' = current_image
	new_image' = new_image
	status' = status
	version_report' = version_report
	out_secondaries' = out_secondaries
	vehicle_version_manifest' = vehicle_version_manifest
	all_version_reports' = all_version_reports

	-- Track
	Track.op' = DoNothing
	verification_repo' = verification_repo
}

-------------------------------
--- Initial state condition ---
-------------------------------
pred Init [] {
	-- The ECUs should have some initial metadata 
	one (PrimaryECU.current_metadata & RootMetadata)
	--one (PrimaryECU.current_metadata & TimestampMetadata)
	--one (PrimaryECU.current_metadata & TargetsMetadata)
	--one (PrimaryECU.current_metadata & SnapshotMetadata)

	no Track.verification_repo
	no Track.op
	PrimaryECU.status = Success

	
}

---------------------------
--- Transition relation ---
---------------------------
/* SendMetadataToPrimary, SendMetadataToSecondaries, 
   FullVerification, FullVerificationTargetsMatch,
   FullVerificationRoot, FullVerificationTargets, 
   FullVerificationTimestamp, FullVerificationSnapshot,
	 VerifyImage, SendVehicleVersionManifest, SendECUVersionReport,
   DoNothing
*/

pred Trans [] {
	SendMetadataToPrimary[DirectorRepo, PrimaryECU] or
	SendMetadataToSecondaries[PrimaryECU, SecondaryECU] or
	FullVerification[PrimaryECU] or
	FullVerificationTargetsMatch[PrimaryECU] or
	PartialVerification[SecondaryECU]

	or

	(some r: RootMetadata | FullVerificationRoot[PrimaryECU, r]) or
	(some t: TimestampMetadata | FullVerificationTimestamp[PrimaryECU, t]) or
	(some s: SnapshotMetadata | FullVerificationSnapshot[PrimaryECU, s]) or
	(some t: TargetsMetadata | FullVerificationTargets[PrimaryECU, t]) 

	or
       
	--(some e: ECU | some i : Image | some t: TargetsMetadata | VerifyImage[e, i, t]) or
	--SendVehicleVersionManifest[PrimaryECU] or
	--(some s: SecondaryECU | SendECUVersionReport[s]) or

	DoNothing[]
}

-----------------
--- Scheduler ---
-----------------

-- All traces are according to the scheduler
-- Can make this a predicate, and make assertions in terms of the predicate
pred Scheduler {
  Init and always Trans

  Track.op = none
}

pred Environment {
	-- Different files should produce different hashes
	--all disj m1, m2: Metadata | no (m1.hashes & m2.hashes)


	--- Metadata Constraints ---
	-- Roles correspond to metadata types-- this is purely to provide a shorthand
	-- for some pre/postconditions; the role field is not strictly necessary
	always all m : Metadata |
		(m.role = Root => m in RootMetadata) and
		(m.role = Targets => m in TargetsMetadata) and
		(m.role = Timestamp => m in TimestampMetadata) and
		(m.role = Snapshot => m in SnapshotMetadata) 	


	--- Time Server Constraints ---
	-- Time always moves forward unless we're looping at the last time
	always (lt[TimeServer.current_time, TimeServer.current_time'] or
		   (TimeServer.current_time = last and TimeServer.current_time' = last))

	--- Other constraints ---
	-- The signature count field correlates with the cardinality of the signatures field
	always all disj m1, m2: Metadata | (#(m1.signatures) < #(m2.signatures)) implies 
	                                   lt [m1.signature_count, m2.signature_count] 
}

run { 
	Scheduler 

	Environment

	eventually Track.op = FullVerificationTargetsMatch

	eventually Track.op = FullVerification
} for 8 but 15 Time, 15 MyTime

assert A_a {
	-- Targets metadata must have one or more associated images
	(Scheduler and Environment) implies 
	always all t : TargetsMetadata | some t.image_hashes && some t.image_filesizes
}
check A_a for 15

assert A_b {
	-- The Targets hashes and filesizes relations must refer to the same set of images
	(Scheduler and Environment) implies 
	always all t : TargetsMetadata | t.image_hashes.Hash = t.image_filesizes.FileSize
}
check A_b for 15

assert A_c {
	-- Snapshot metadata has info about all targets metadata in repo
	(Scheduler and Environment) implies 
	always all s : SnapshotMetadata | s.targets_info.Version = TargetsMetadata
}
check A_c for 15

assert A_d {
	-- Each timestamp metadata file keeps track of one latest snapshot metadata file
	-- and contains a non-zero number of hashes for that file
	(Scheduler and Environment) implies 
	always all t : TimestampMetadata | one t.latest_snapshot && some t.snapshot_hashes
}
check A_d for 15

assert A_e {
    -- Primary ECUs always have a full set of metadata
	(Scheduler and Environment) implies 
	always all p : PrimaryECU | #(p.current_metadata) = 4 && 
								  one (p.current_metadata & RootMetadata) && 
								  one (p.current_metadata & TargetsMetadata) && 
								  one (p.current_metadata & SnapshotMetadata) && 
								  one (p.current_metadata & TimestampMetadata)
}
check A_e for 15

assert A_f {
	-- The director repository always either sends a full set of metadata to the primary ECU,
    -- or sends nothing
	(Scheduler and Environment) implies 
	always all d : DirectorRepo | no d.out_primary ||
								  (
								      #(d.out_primary) = 4 && 
								   	  one (d.out_primary & RootMetadata) && 
								   	  one (d.out_primary & TargetsMetadata) && 
								  	  one (d.out_primary & SnapshotMetadata) && 
								  	  one (d.out_primary & TimestampMetadata)
								  )
}
check A_f for 15
