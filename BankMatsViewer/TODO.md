# BankMatsViewer TODO

## Next Session

- [ ] Fix first-hover unknown item visuals after bulk AH import.
  - Symptom: newly imported items can render as question-mark/unknown on first hover and only resolve on second hover.
  - Goal: pre-warm item data and force a deterministic repaint once GET_ITEM_INFO_RECEIVED returns for imported IDs.
  - Candidate approach:
    - Track newly imported IDs in a pending set.
    - On GET_ITEM_INFO_RECEIVED for those IDs, clear pending state and refresh visible rows/buttons.
    - Optionally delay initial draw of unresolved imported IDs until icon/name is available.

- [ ] Add auto-tagging for newly imported items to reduce "Other" buckets (especially TWW/Midnight).
  - Goal: map item subtypes/profession hints to stable families immediately after import.
  - Start with aliases for likely noisy families:
    - Finishing Reagents
    - Parts / Devices
    - Gems
    - Enchantment
    - Pigments and Ink
  - Validate by checking Midnight/TWW sections after /bmats importah.

## Notes

- AH import flow is now working and fast:
  - Auto path: AUCTION_HOUSE_BROWSE_RESULTS_UPDATED
  - Manual path: /bmats importah (browse + replicate snapshot)
  - Chat feedback confirms request and completion counts.
