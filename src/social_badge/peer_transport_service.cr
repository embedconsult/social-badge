require "uuid"
require "uri"
require "./timeline_service"
require "./meshtastic_envelope_service"
require "./meshtastic_adapter_service"

module SocialBadge
  class PeerTransportService
    DEFAULT_MAX_ATTEMPTS = 5

    def initialize(
      @timeline : TimelineService,
      @envelopes : MeshtasticEnvelopeService = MeshtasticEnvelopeService.new,
      @max_attempts : Int32 = DEFAULT_MAX_ATTEMPTS,
      @adapter : MeshtasticAdapterService = MeshtasticAdapterService.new,
    )
      @jobs = [] of OutboundRelayJob
      @jobs_by_id = {} of String => OutboundRelayJob
    end

    def queue(limit : Int32 = 25) : Array(OutboundRelayJob)
      @jobs.last(limit).reverse
    end

    def enqueue(peer_url : String, message_id : String) : OutboundRelayJob
      normalized_peer_url = normalize_peer_url(peer_url)
      message = @timeline.message(message_id)
      raise KeyError.new("Unknown message id") unless message

      envelope = @envelopes.build_from(message, @timeline.identity.trust_level)
      job = OutboundRelayJob.new(
        id: UUID.random.to_s,
        peer_url: normalized_peer_url,
        envelope: envelope,
      )
      @jobs << job
      @jobs_by_id[job.id] = job
      job
    end

    def mark_delivered(job_id : String) : OutboundRelayJob
      job = fetch_job(job_id)
      job.status = RelayJobStatus::Delivered
      job
    end

    def mark_failure(job_id : String) : OutboundRelayJob
      job = fetch_job(job_id)
      return job if job.status == RelayJobStatus::Delivered
      return job if job.status == RelayJobStatus::Failed

      job.attempts += 1
      if job.attempts >= @max_attempts
        job.status = RelayJobStatus::Failed
      else
        job.next_attempt_at = Time.utc + backoff(job.attempts)
      end
      job
    end

    def receive(envelope : MeshtasticEnvelope) : Message?
      @timeline.receive(envelope)
    end

    def payload_base64(job_id : String) : String
      job = fetch_job(job_id)
      @adapter.encode_base64(job.envelope)
    end

    def receive_payload(encoded_payload : String) : Message?
      envelope = @adapter.decode_base64(encoded_payload)
      receive(envelope)
    end

    private def fetch_job(job_id : String) : OutboundRelayJob
      @jobs_by_id[job_id]? || raise KeyError.new("Unknown relay job id")
    end

    private def normalize_peer_url(peer_url : String) : String
      parsed = URI.parse(peer_url)
      scheme = parsed.scheme
      host = parsed.host
      raise ArgumentError.new("Invalid peer URL") unless scheme && (scheme == "http" || scheme == "https") && host
      peer_url
    rescue URI::Error
      raise ArgumentError.new("Invalid peer URL")
    end

    private def backoff(attempts : Int32) : Time::Span
      seconds = 30 * (2 ** (attempts - 1))
      seconds = 900 if seconds > 900
      seconds.seconds
    end
  end
end
