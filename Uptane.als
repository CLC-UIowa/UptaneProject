--- WORK IN PROGRESS ---

--- Questions ---
-- 1. How to model version number?
-- 2. Use Filename sig, or just directly link with other files? Specific types of filenames?
-- 3. Modeling time server?

--- Components/actors ---
abstract sig Repository {}
one sig DirectorRepo extends Repository {
	-- metadata
}
one sig ImageRepo extends Repository  {
	-- metadata
	database: set Image
}
abstract sig ECU {
	key: ECUKey
}
one sig PrimaryECU extends ECU {
	current_metadata: set Metadata,
	out_repo: Message -> lone Repository,
	out_secondary: Message -> SecondaryECU
}
some sig SecondaryECU extends ECU  {}


--- IDs ---
abstract sig ID {}
sig VehicleID, ECUId, KeyID extends ID {}


--- Vehicle and ECU Data ---
sig ECUVersionReport {
	signatures: set Signature,
	id: ECUId,
	image_file: Filename,
	image_hash: Hash 
}
sig VehicleVersionManifest {
	signatures: set Signature,
	vehicle_id: VehicleID,
	ecu_id: ECUId,
	version_report: set ECUVersionReport
}
sig InventoryDatabaseEntry {
	vehicle_id: VehicleID,
	ecus: ECUId -> VehicleID -> ECUKey -> KeyID
}

--- Files ---
sig Filename {}
sig Image {
	filename: Filename
}


--- Authentication ---
sig Key {
	id: KeyID
}
sig ECUKey extends Key {}
abstract sig Hash {
	-- Split into image and metadata hashes?
}
sig Signature {
	key_id: KeyID,
}

--- Metadata ---
abstract sig Metadata {
	signatures: set Signature
}
sig Root extends Metadata {
	public_keys: set Key
}
sig Timestamp extends Metadata {
	latest_snapshot: Filename
}
sig Snapshot extends Metadata {
	targets_info: set Filename
}
sig Targets extends Metadata {
	ecu_info: Filename -> Hash
}


--- Communication ---
abstract sig Message {} 
sig MetadataMessage extends Message {
	root: lone Root,
	timestamp: lone Timestamp,
	snapshot: lone Snapshot,
	targets: lone Targets,
	-- Where does sender/receiver info go?
}
sig ImageMessage extends Message {
	image: Image
}
sig ManifestMessage extends Message {
	
}



fact {
	#SecondaryECU > 2
}
