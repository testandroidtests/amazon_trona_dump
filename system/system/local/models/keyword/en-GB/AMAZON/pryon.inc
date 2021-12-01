# top-level config file for Pryon Standup recognizer

# Note: despite some appearances, the float values in this file are very low
# precision, and thus help reduce cross-platform numerical differences

# Front End
fe.type = "LFBE"

fe.audio_analysis.dither = 0.0
fe.audio_analysis.frame_length_milli = 25
fe.audio_analysis.frame_shift_milli = 10
fe.audio_analysis.preemphasis_coeff = 0.96875
fe.audio_analysis.remove_dc_offset = 1
fe.audio_analysis.round_to_power_of_two = 1
fe.audio_analysis.samplerate = 16000
fe.audio_analysis.window_type = "povey"

fe.mel_fbank.high_freq = 6000
fe.mel_fbank.low_freq = 100
fe.mel_fbank.num_bins = 20

fe.cep.cepstral_lifter = 22
fe.cep.energy_floor = 0
fe.cep.num_cepstrum = 20
fe.cep.raw_energy = 1
fe.cep.use_energy = 0

fe.plp.cepstral_scale = 1
fe.plp.compress_factor = 0.3330078125
fe.plp.lpc_order = 12

# ------------------------------------------
# CONTINUOUSLY DECAYING cmn processing--bridges across all utts
# processed, but each frame's influence decays with constant below.
# decay-weight between 0 and 1

# initialize CMS/CVN
fe.feat.mean_and_var_stats_file_path = ""

# adaptation on
fe.feat.adapt_norm_stats = 1

# continuous est, update as we go (0 = end of utt)
fe.feat.continuous_norm_estimation = 1

# The decay weight is optimized for the WSJ test-set.
# Eventually a larger value is necessary if used with shorter utterances.
fe.feat.current_frame_decay_weight = 0.003

fe.feat.do_mean_norm = 1
fe.feat.do_variance_norm = 0

# Buffer until we have at least min_frames data to start streaming (only affects 1st utt)
fe.feat.min_frames_norm = 100

# This is the "infinite" window size in frames.
# -1 is for batch mode.  After vsn > = 1989
fe.feat.norm_window_size = 2147483647

# --------------------------------

# LDA
fe.feat.stack_left = 20
fe.feat.stack_right = 10
fe.feat.transform_filepath = ""

# FMLLR matrix for the environment
fe.feat.affine_transform_filepath = ""

# scorer
scorer.model_filetype = "kaldi-mlp"
scorer.model_filepath = "kaldi_dnn.mlp"
scorer.batch_size = 6
scorer.acoustic_scale = 0.05
scorer.max_approx = 1
scorer.shortlist_size = 0
scorer.pdfcounts_filepath = "pdf.counts"
scorer.globalMeanVar_filepath = "train_glob.cmvn"
# scorer upsampling
scorer.score_upsampling.enable = 1
scorer.score_upsampling.default_skip_frame_count = 1
scorer.score_upsampling.fallback_skip_frame_count = 2
scorer.score_upsampling.fallback_backlog_threshold_msec = 2147483647

# upsampling situations for testing
# disable-upsampling
scorer.score_upsampling.enable#disable-upsampling = 0

# force-upsampling-default (prevents fallback mode by setting threshold to infinity)
scorer.score_upsampling.enable#force-upsampling-default = 1
scorer.score_upsampling.fallback_backlog_threshold_msec#force-upsampling-default = 2147483647

# force-upsampling-fallback (use fallback mode always)
scorer.score_upsampling.enable#force-upsampling-fallback = 1
scorer.score_upsampling.fallback_backlog_threshold_msec#force-upsampling-fallback = 0


# keyword spotter
search.decoder_type = "kaldi-key-phrase"
search.trans_filepath = "final.trans"
keyword_spotter.config_filepath = "kw.cfg.json"
keyword_spotter.op_config_filepath = "op.cfg.json"
keyword_spotter.emit_nearmiss = 1

#fingerprinter
fingerprinter.enabled = 1

# results
id2word.mapping_filepath = "words.shrunk.txt"
