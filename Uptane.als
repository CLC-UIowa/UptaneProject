open util/ordering[Version]
open util/ordering[SignatureCount]
open util/ordering[FileSize]
open util/ordering[MyTime]

--- WORK IN PROGRESS ---
--- Snapshot -> Electrum

--- Old Questions ---
-- 1. How to model version number? Same as time
-- 2. Use Filename sig, or just directly link with other files? Specific types of filenames?
--    If a filename is only a means to get the file, it is an implementation issue

-- New questions
-- 1. Modeling threshold signatures-- how to map SignatureCount sig to set of signatures size
-- 2. Some properties are enforced by our transitions-- should they also be listed as facts?
-- 3. Operations (like sending metadata to Primary ECU) are defined to be bulletproof in this model. Do we
--    need to define the model in a certain way that allows these assumptions to be relaxed?
-- 4. Manually using MyTime and TimeServer sigs
-- 5. Correlating a set of signatures with a signature count
-- 6. Model getting too big to look at in the inspector
-- 7. How does reporting failures work if preconditions must be met for transitions to take place


-- Ordered relations: Version number, signature count, time stamp, file size
-- Links that are skipped because they are aliases-- file name, key ID (?), MAYBE hash

-------------------------
--- Components/actors ---
-------------------------
abstract sig Repository {
	var out_primary: set Metadata,
}
one sig DirectorRepo extends Repository {
}
one sig ImageRepo extends Repository  {
	--database: set Image,
	--var out_primary: set Metadata,
}
abstract sig ECU {
	--key: ECUKey,
	var current_metadata: set Metadata,
	var new_metadata: set Metadata,
}
one sig PrimaryECU extends ECU {
	-- current message vs message log
	-- snapshot vs whole system
	--out_repo: Message -> lone Repository,
	var out_secondaries: set Metadata,
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
	--signatures: set Signature,
	--id: ECUId,
	--image_file: Image,
	--image_hash: Hash, 
}
sig VehicleVersionManifest {
	--signatures: set Signature,
	--vehicle_id: VehicleID,
	--ecu_id: ECUId,
	--version_report: set ECUVersionReport,
}
sig InventoryDatabaseEntry {
	--vehicle_id: VehicleID,
	--ecus: ECUId -> VehicleID -> ECUKey -> KeyID, -- Arity 5 issue
}

-------------
--- Files ---
-------------
--sig Filename {}
sig Image {}


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
	hashes: some Hash
}
sig RootMetadata extends Metadata {
	-- public_keys: set Key,
	key_mapping: Role lone -> some MetadataKey,
	signature_count_mapping: Role -> one SignatureCount
	-- can add additional fields for delegations roles if necessary
}
sig TargetsMetadata extends Metadata {
	image_hashes: Image -> some Hash,
	image_filesizes: Image -> one FileSize,
	delegations: lone DelegationsMetadata,
	-- ECU INFO?
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
enum Operator { SendMetadataToPrimary, SendMetadataToSecondaries, FullVerification, FullVerificationRoot, DoNothing }
one sig Track{ var op: lone Operator }

-- Write a new set of metadata
-- Send set of metadata from Director to ECUs
-- Send set of metadata from Primary ECU to Secondary ECUs
-- Full verification of a metadata set
-- Partial verification of a metadata set

pred NoChangeExceptDirector[r: DirectorRepo -> univ, D: set DirectorRepo] {
	all d: DirectorRepo - D | d.r' = d.r
}

pred NoChangeExceptPrimary[r: PrimaryECU -> univ, P: set PrimaryECU] {
	all p: PrimaryECU - P | p.r' = p.r
}

pred SendMetadataToPrimary[r: Repository, p: PrimaryECU] {
	-- NOTE-- should this be in batch? or one metadata file at a time?
	--- Preconditions ---
	-- The director sends a full set of metadata
	one (r.out_primary & TargetsMetadata) 
	one (r.out_primary & SnapshotMetadata) 
	one (r.out_primary & TimestampMetadata)
								  

	--- Postconditions ---
	-- Update out_primary field of Director
	no r.out_primary'
	-- Update new_metadata field of primary ECU
	p.new_metadata' = r.out_primary
	Track.op' = SendMetadataToPrimary

	--- Frame conditions ---
	NoChangeExceptDirector[out_primary, r]
	NoChangeExceptPrimary[current_metadata, none]
	NoChangeExceptPrimary[new_metadata, p]	
	NoChangeExceptPrimary[out_secondaries, none]
--	NoChangeExceptPrimary[out_secondaries, none]
}

pred SendMetadataToSecondaries[p: PrimaryECU, S: set SecondaryECU] {
	--- Preconditions ---
	-- The primary must be broadcasting to all secondaries (?)
--	S = SecondaryECU
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
	NoChangeExceptDirector[out_primary, none]
	NoChangeExceptPrimary[current_metadata, none]
	NoChangeExceptPrimary[new_metadata, none]
	NoChangeExceptPrimary[out_secondaries, p]
}

pred FullVerificationRoot[p: PrimaryECU] {
	-- If there is no new root metadata, that is OK
	-- Maybe for this, we will introduce another predicate


	---------------------
	--- Preconditions ---
	---------------------

	-- Check signature count with current and new root metadata (compare to threshold)
	gte[
		(p.new_metadata & RootMetadata).signature_count, 
       ((p.current_metadata & RootMetadata).signature_count_mapping)[Root]
	]

	gte[
		(p.new_metadata & RootMetadata).signature_count, 
       ((p.new_metadata & RootMetadata).signature_count_mapping)[Root]
	]

	-- Check validity of signatures with current and new root metadata
	all s: (p.new_metadata & RootMetadata).signatures |
		s.key in (p.current_metadata & RootMetadata).key_mapping[Root]

	all s: (p.new_metadata & RootMetadata).signatures |
		s.key in (p.new_metadata & RootMetadata).key_mapping[Root]

	-- Check version number
	lte[ 
		(p.new_metadata & RootMetadata).version, 
    	(p.current_metadata & RootMetadata).version 
  	]

	-- Check expiration timestamp
	lt[
		TimeServer.current_time,
	   (p.new_metadata & RootMetadata).expiration
	]
		

	----------------------
	--- Postconditions ---
	----------------------

	-- Update to the latest version of Root metadata
	(p.current_metadata' & RootMetadata) = (p.new_metadata & RootMetadata)

	-- If Timestamp or Snapshot keys have been rotated, delete those metadata files
	((p.new_metadata & RootMetadata).key_mapping[Timestamp] !=
	 (p.current_metadata & RootMetadata).key_mapping[Timestamp]) =>
	(p.current_metadata' & TimestampMetadata) = none

	((p.new_metadata & RootMetadata).key_mapping[Snapshot] !=
	 (p.current_metadata & RootMetadata).key_mapping[Snapshot]) =>
	(p.current_metadata' & SnapshotMetadata) = none

	Track.op' = FullVerificationRoot


	------------------------
	--- Frame Conditions ---
	------------------------

	NoChangeExceptDirector[out_primary, none]
	NoChangeExceptPrimary[current_metadata,p]
	NoChangeExceptPrimary[new_metadata, none]
	NoChangeExceptPrimary[out_secondaries, none]

}

pred FullVerification[p: PrimaryECU] {
	-- Note 1: We need to have metadata from the director AND image repos (maybe take in repo as argument).
	-- Note 2: Need to deal with delegations. 
	-- Note 3: Targets metadata ECU information? See "custom metadata about images"
	-- Note 4: Should be able to take SecondaryECU as input
	-- Note 5: Need to be able to handle cases where current metadata does not exist
	
	---------------------
	--- Preconditions ---
	---------------------
	-- new metadata is a full set of metadata
	one (p.new_metadata & TargetsMetadata) 
	one (p.new_metadata & SnapshotMetadata) 
	one (p.new_metadata & TimestampMetadata)

	-- Compare current snapshot metadata hashes and version to 
	-- hashes and version in new timestamp (make sure there's a 
	-- new update)
	(p.current_metadata & SnapshotMetadata).hashes != 
	(p.new_metadata & TimestampMetadata).snapshot_hashes.HashFunction
	||
	(p.current_metadata & SnapshotMetadata).version != 
	(p.new_metadata & TimestampMetadata).latest_snapshot[SnapshotMetadata]	

	-- Make sure there are targets
	some (p.new_metadata & TargetsMetadata).image_hashes

	-- Make sure version numbers of targets in the snapshots metadata do not decrease
	all t: (p.current_metadata & SnapshotMetadata).targets_info.Version |
		lte[
			(p.current_metadata & SnapshotMetadata).targets_info[t],
			(p.new_metadata & SnapshotMetadata).targets_info[t]
		]

	-- New metadata is not older version
	all m1: p.current_metadata | all m2: p.new_metadata |
		(m1.role = m2.role) =>
		lte[ 
			m1.version, 
    		m2.version 
  		] 

	-- Target metadata version number should match the version number
	-- listed in snapshot metadata
	let t = (p.new_metadata & TargetsMetadata) |
		t.version = (p.current_metadata & SnapshotMetadata).targets_info[t]

	-- Check signature count (compare to threshold)

	all m: Metadata | 
		gte[
			m.signature_count, 
            ((p.current_metadata & RootMetadata).signature_count_mapping)[m.role]
		]

	-- Check validity of signatures
	all m: p.new_metadata | all s: m.signatures |
		s.key in (p.current_metadata & RootMetadata).key_mapping[m.role]

	-- Note-- same key doing multiple signatures?

	-- Metadata cannot be expired
	lt[
		TimeServer.current_time, 
		(p.new_metadata).expiration
	]

	----------------------
	--- Postconditions ---
	----------------------
	p.current_metadata' = p.new_metadata
	Track.op' = FullVerification
	
	------------------------
	--- Frame Conditions ---
	------------------------
	NoChangeExceptDirector[out_primary, none]
	NoChangeExceptPrimary[current_metadata,p]
	NoChangeExceptPrimary[new_metadata, none]
	NoChangeExceptPrimary[out_secondaries, none]
}

pred DoNothing[] {
	out_primary' = out_primary
	current_metadata' = current_metadata
	new_metadata' = new_metadata
	Track.op' = DoNothing
}

-------------------------------
--- Initial state condition ---
-------------------------------
pred Init [] {
 -- to do
	-- The ECUs should have some initial metadata
}

---------------------------
--- Transition relation ---
---------------------------
pred Trans [] {
    (some p: PrimaryECU | 
        SendMetadataToPrimary[DirectorRepo, p] ||
		SendMetadataToSecondaries[p, SecondaryECU] ||
		FullVerification[p] ||
		FullVerificationRoot[p])

		||
       
	    DoNothing[]
}

-----------------
--- Scheduler ---
-----------------

-- All traces are according to the scheduler
fact Scheduler {
  Init and always Trans

  Track.op = none
}

fact {
	-- Different files should produce different hashes
	-- But, this isn't necessarily true? Only most of the time :)


	--- Metadata Constraints ---
	-- Roles correspond to metadata types-- this is purely to provide a shorthand
	-- for some pre/postconditions; the role field is not strictly necessary
	always all m : Metadata |
		(m.role = Root => m in RootMetadata) &&
		(m.role = Targets => m in TargetsMetadata) &&
		(m.role = Timestamp => m in TimestampMetadata) &&
		(m.role = Snapshot => m in SnapshotMetadata) 	


	-- Make generic metadata rule for any pair of metadata,
	-- #set Signature 1 > #set Signature 2 iff
	-- signature_count 1 > signature_count 2
	-- Then, we can compare generic signature count in Metadata to threshold signature count in root

	--- Time Server Constraints ---
	-- Time always moves forward unless we're looping at the last time
	always (lt[TimeServer.current_time, TimeServer.current_time'] or
		   (TimeServer.current_time = last and TimeServer.current_time' = last))

	--- Other constraints ---
	-- The signature count field correlates with the cardinality of the signatures field
	always all disj m1, m2: Metadata | (#(m1.signatures) < #(m2.signatures)) => 
	                                   lt [m1.signature_count, m2.signature_count] 
}

run { 
		eventually Track.op = SendMetadataToPrimary 
		eventually Track.op = SendMetadataToSecondaries
		eventually Track.op = FullVerificationRoot
		eventually Track.op = FullVerification	
	} for 10


assert A_a {
	-- Targets metadata must have one or more associated images
	always all t : TargetsMetadata | some t.image_hashes && some t.image_filesizes
}
check A_a for 15

assert A_b {
	-- The Targets hashes and filesizes relations must refer to the same set of images
	always all t : TargetsMetadata | t.image_hashes.Hash = t.image_filesizes.FileSize
}
check A_b for 15

assert A_c {
	-- Snapshot metadata has info about all targets metadata in repo
	always all s : SnapshotMetadata | s.targets_info.Version = TargetsMetadata
}
check A_c for 15

assert A_d {
	-- Each timestamp metadata file keeps track of one latest snapshot metadata file
	-- and contains a non-zero number of hashes for that file
	always all t : TimestampMetadata | one t.latest_snapshot && some t.snapshot_hashes
}
check A_d for 15

assert A_e {
    -- Primary ECUs always have a full set of metadata
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
