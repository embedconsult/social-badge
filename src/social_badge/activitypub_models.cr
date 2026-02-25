require "json"

module SocialBadge
  struct WebFingerLink
    include JSON::Serializable

    getter rel : String
    getter type : String
    getter href : String

    def initialize(@rel : String, @type : String, @href : String)
    end
  end

  struct WebFingerResponse
    include JSON::Serializable

    getter subject : String
    getter links : Array(WebFingerLink)

    def initialize(@subject : String, @links : Array(WebFingerLink))
    end
  end

  struct ActivityPubPublicKey
    include JSON::Serializable

    getter id : String
    getter owner : String
    @[JSON::Field(key: "publicKeyPem")]
    getter public_key_pem : String

    def initialize(@id : String, @owner : String, @public_key_pem : String)
    end
  end

  struct ActivityPubActor
    include JSON::Serializable

    @[JSON::Field(key: "@context")]
    getter context : Array(String)
    getter id : String
    getter type : String
    @[JSON::Field(key: "preferredUsername")]
    getter preferred_username : String
    getter name : String
    getter inbox : String
    getter outbox : String
    @[JSON::Field(key: "publicKey")]
    getter public_key : ActivityPubPublicKey

    def initialize(
      @context : Array(String),
      @id : String,
      @type : String,
      @preferred_username : String,
      @name : String,
      @inbox : String,
      @outbox : String,
      @public_key : ActivityPubPublicKey,
    )
    end
  end

  struct ActivityPubNote
    include JSON::Serializable

    @[JSON::Field(key: "@context")]
    getter context : Array(String)?
    getter id : String
    getter type : String
    getter content : String
    @[JSON::Field(key: "mediaType")]
    getter media_type : String?
    getter attributedTo : String?
    getter published : String?

    def initialize(
      @id : String,
      @type : String,
      @content : String,
      @media_type : String? = nil,
      @attributedTo : String? = nil,
      @published : String? = nil,
      @context : Array(String)? = nil,
    )
    end
  end

  struct ActivityPubCreate
    include JSON::Serializable

    @[JSON::Field(key: "@context")]
    getter context : Array(String)
    getter id : String
    getter type : String
    getter actor : String
    getter object : ActivityPubNote
    getter published : String

    def initialize(
      @context : Array(String),
      @id : String,
      @type : String,
      @actor : String,
      @object : ActivityPubNote,
      @published : String,
    )
    end
  end

  struct ActivityPubOrderedCollection
    include JSON::Serializable

    @[JSON::Field(key: "@context")]
    getter context : Array(String)
    getter id : String
    getter type : String
    getter totalItems : Int32
    getter orderedItems : Array(ActivityPubCreate)

    def initialize(
      @context : Array(String),
      @id : String,
      @type : String,
      @totalItems : Int32,
      @orderedItems : Array(ActivityPubCreate),
    )
    end
  end
end
