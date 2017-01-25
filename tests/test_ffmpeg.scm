;; AIscm - Guile extension for numerical arrays and tensors.
;; Copyright (C) 2013, 2014, 2015, 2016, 2017 Jan Wedekind <jan@wedesoft.de>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
(use-modules (oop goops)
             (srfi srfi-1)
             (aiscm ffmpeg)
             (aiscm element)
             (aiscm int)
             (aiscm float)
             (aiscm rgb)
             (aiscm image)
             (aiscm pointer)
             (aiscm sequence)
             (guile-tap))
(load-extension "libguile-aiscm-tests" "init_tests")

(define input-video (open-ffmpeg-input "fixtures/av-sync.mp4"))
(define audio-mono (open-ffmpeg-input "fixtures/mono.mp3"))
(define audio-stereo (open-ffmpeg-input "fixtures/test.mp3"))
(define image (open-ffmpeg-input "fixtures/fubk.png"))

(define video-pts0 (video-pts input-video))
(define video-frame (read-image input-video))
(define video-pixel (get (to-array video-frame) 10 270))
(define video-pts1 (video-pts input-video))
(define video-frame (read-image input-video))
(define video-pts2 (video-pts input-video))

(pts= input-video 15)
(read-image input-video)
(define video-position (video-pts input-video))

(define audio-pts0 (audio-pts audio-mono))
(define audio-mono-frame (read-audio audio-mono))
(define audio-sample (get audio-mono-frame 0 300))
(define audio-pts1 (audio-pts audio-mono))
(read-audio audio-mono)
(define audio-pts2 (audio-pts audio-mono))

(define audio-stereo-frame (read-audio audio-stereo))

(define full-video (open-ffmpeg-input "fixtures/av-sync.mp4"))
(define images (map (lambda _ (read-image full-video)) (iota 2253)))
(define full-audio (open-ffmpeg-input "fixtures/test.mp3"))
(define samples (map (lambda _ (read-audio full-audio)) (iota 1625)))

(define-class <dummy> ()
  (buffer #:init-value '())
  (clock  #:init-value 0))

(ok (null? (from-array-empty))
    "Convert empty integer array to Scheme array")
(ok (equal? '(2 3 5) (from-array-three-elements))
    "Convert integer array with three elements to Scheme array")
(ok (equal? '(2 3 5) (from-array-stop-at-zero))
    "Convert integer array to Scheme array stopping at first zero element")
(ok (equal? '(0) (from-array-at-least-one))
    "Convert zero array with minimum number of elements")
(ok (first-offset-is-zero)
    "First value of offset-array is zero")
(ok (second-offset-correct)
    "Second value of offset-array correct")
(ok (zero-offset-for-null-pointer)
    "Set offset values for null pointers to zero")
(ok (pack-byte-audio-sample)
    "Pack byte audio sample")
(ok (pack-byte-audio-samples)
    "Pack byte audio samples")
(ok (pack-short-int-audio-samples)
    "Pack short integer audio samples")
(ok (equal? '(640 360) (shape input-video))
    "Check frame size of input video")
(ok (throws? (open-ffmpeg-input "fixtures/no-such-file.avi"))
    "Throw error if file does not exist")
(ok (throws? (shape audio-mono))
    "Audio file does not have width and height")
(ok (equal? '(640 360) (shape video-frame))
    "Check shape of video frame")
(ok (is-a? video-frame <image>)
    "Check that video frame is an image object")
(ok (eqv? 25 (frame-rate input-video))
    "Get frame rate of video")
(ok (throws? (frame-rate audio-mono))
    "Audio file does not have a frame rate")
(ok (not (cadr (list (read-image image) (read-image image))))
    "Image has only one video frame")
(ok (equal? (rgb 154 154 154) video-pixel)
    "Check a pixel in the first video frame of the video")
(ok (equal? (list 0 0 (/ 1 25)) (list video-pts0 video-pts1 video-pts2))
    "Check first three video frame time stamps")
(ok (last images)
    "Check last image of video was read")
(ok (not (read-image full-video))
    "Check 'read-image' returns false after last frame")
(ok (eqv? 1 (channels audio-mono))
    "Detect mono audio stream")
(ok (eqv? 2 (channels input-video))
    "Detect stereo audio stream")
(ok (throws? (channels image))
    "Image does not have audio channels")
(ok (eqv? 8000 (rate audio-mono))
    "Get sampling rate of audio stream")
(ok (throws? (rate image))
    "Image does not have an audio sampling rate")
(ok (eq? <sint> (typecode audio-mono))
    "Get type of audio samples")
(ok (throws? (typecode image))
    "Image does not have an audio sample type")
(ok (is-a? audio-mono-frame <sequence<>>)
    "Check that audio frame is an array")
(ok (eqv? 2 (dimensions audio-mono-frame))
    "Audio frame should have two dimensions")
(ok (eq? <sint> (typecode audio-mono-frame))
    "Audio frame should have samples of correct type")
(ok (eqv? 1 (car (shape audio-mono-frame)))
    "Mono audio frame should have 1 as first dimension")
(ok (eqv? 2 (car (shape audio-stereo-frame)))
    "Stereo audio frame should have 2 as first dimension")
(ok (eqv? 40 audio-sample)
    "Get a value from a mono audio frame")
(diagnostics "Following test disabled because number of audio frames depends on FFmpeg version")
(skip (not (read-audio full-audio)); number of audio frames depends on FFmpeg version
    "Check 'read-audio' returns false after last frame")
(ok (equal? (list 0 0 (/ 3456 48000)) (list audio-pts0 audio-pts1 audio-pts2))
    "Check first three audio frame time stamps")
(diagnostics "Following test should not hang")
(ok (not (read-audio image))
    "Do not hang when reading audio from image")
(ok (<= 15 video-position)
    "Seeking audio/video should update the video position")
(let [(image (open-ffmpeg-input "fixtures/fubk.png"))]
  (read-audio image)
  (ok (read-image image)
      "Cache video data when reading audio"))
(let [(dummy (make <dummy>))]
  (ok (not (ffmpeg-buffer-pop dummy 'buffer 'clock))
      "Popping buffer should return #f when empty"))
(let [(dummy (make <dummy>))]
  (ffmpeg-buffer-push dummy 'buffer (cons 123 'dummy-frame))
  (ffmpeg-buffer-push dummy 'buffer (cons 456 'other-frame))
  (ok (eq? 'dummy-frame (ffmpeg-buffer-pop dummy 'buffer 'clock))
      "Popping buffer should return first frame")
  (ok (eq? 123 (slot-ref dummy 'clock))
      "Popping buffer should set the time stamp")
  (ok (eq? 'other-frame (ffmpeg-buffer-pop dummy 'buffer 'clock))
      "Popping buffer again should return the second frame")
  (ok (eq? 456 (slot-ref dummy 'clock))
      "Popping buffer again should set the time stamp"))
(run-tests)
