# Seeds for CT Liver Segmentation Platform

puts "🌱 Seeding CT Liver Segmentation data..."

# Create sample CT scans
puts "Creating sample CT scans..."
ct_scans = []

5.times do |i|
  ct_scan = CtScan.create!(
    patient_id: "DEMO_#{(i + 1).to_s.rjust(4, '0')}",
    study_date: Date.current - rand(30).days,
    modality: 'CT',
    slice_count: [80, 100, 120, 150].sample,
    status: ['uploaded', 'processing', 'completed'].sample,
    dicom_series: {
      series_description: 'CT Abdomen with Contrast',
      institution_name: 'Demo Medical Center',
      manufacturer: 'Demo Manufacturer'
    }.to_json,
    slice_images: [
      { io: StringIO.new('Mock CT slice 0'), filename: 'slice_0.jpg' },
      { io: StringIO.new('Mock CT slice 1'), filename: 'slice_1.jpg' },
      { io: StringIO.new('Mock CT slice 2'), filename: 'slice_2.jpg' }
    ]
  )
  
  ct_scans << ct_scan
  puts "  ✓ Created CT scan: #{ct_scan.patient_id}"
end

# Create segmentation tasks and results
puts "\nCreating segmentation tasks..."
ct_scans.each_with_index do |ct_scan, i|
  task = ct_scan.segmentation_tasks.create!(
    status: ['pending', 'processing', 'completed', 'completed', 'completed'].sample,
    started_at: 5.minutes.ago,
    completed_at: ct_scan.status == 'completed' ? Time.current : nil,
    inference_time_ms: rand(5000..15000)
  )

  # Create result for completed tasks
  if task.completed?
    dice = (0.88 + rand * 0.08).round(4)  # 0.88 to 0.96
    iou = (0.85 + rand * 0.07).round(4)   # 0.85 to 0.92
    
    task.create_segmentation_result!(
      dice_coefficient: dice,
      iou_score: iou,
      volume_ml: 1200.0 + rand(500.0),
      mask_file: "tmp/masks/mask_#{i + 1}.nii.gz",
      contours: {
        format: 'json',
        slices: (0...10).map do |j|
          {
            slice_index: j * 10,
            liver_area: rand(5000..10000)
          }
        end
      },
      metrics: {
        pixel_accuracy: 0.95 + rand(0.04),
        sensitivity: 0.92 + rand(0.06),
        specificity: 0.96 + rand(0.03)
      }
    )
    puts "  ✓ Created task and result for: #{ct_scan.patient_id} (Dice: #{dice.round(3)})"
  else
    puts "  ✓ Created pending/processing task for: #{ct_scan.patient_id}"
  end
end

puts "\n✅ Seeding completed!"
puts "\n📊 Summary:"
puts "  • CT Scans: #{CtScan.count}"
puts "  • Segmentation Tasks: #{SegmentationTask.count}"
puts "  • Segmentation Results: #{SegmentationResult.count}"
puts "  • Average Dice: #{SegmentationResult.average(:dice_coefficient)&.round(3) || 'N/A'}"
puts "  • Average IoU: #{SegmentationResult.average(:iou_score)&.round(3) || 'N/A'}"
