import dIcon from "discourse/ui-kit/helpers/d-icon";

// The voice plugin's state icons for someone in a call, with its class, so
// its styles place them.
const VoiceParticipantSuffix = <template>
  <span class="voice-participant-suffix">
    {{#if @suffixArgs.isHandRaised}}
      {{dIcon "hand" title="voice.participant.status_hand_raised"}}
    {{/if}}
    {{#if @suffixArgs.isScreenSharing}}
      {{dIcon "display" title="voice.participant.status_screen_sharing"}}
    {{/if}}
    {{#if @suffixArgs.isVideoOn}}
      {{dIcon "video" title="voice.participant.status_video"}}
    {{/if}}
    {{#if @suffixArgs.isPtt}}
      {{dIcon "walkie-talkie" title="voice.participant.status_ptt"}}
    {{/if}}
    {{#if @suffixArgs.isMuted}}
      {{dIcon "microphone-slash" title="voice.participant.status_muted"}}
    {{/if}}
    {{#if @suffixArgs.isDeafened}}
      {{dIcon "volume-xmark" title="voice.participant.status_deafened"}}
    {{/if}}
  </span>
</template>;

export default VoiceParticipantSuffix;
