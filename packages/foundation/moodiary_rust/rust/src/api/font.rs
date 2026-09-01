use anyhow::Result;
use flutter_rust_bridge::frb;
use std::collections::HashMap;

#[frb(opaque)]
pub struct FontReader {}

impl FontReader {
    pub fn get_font_name_from_ttf(ttf_file_path: String) -> Result<String> {
        moodiary_font::get_font_name_from_ttf(ttf_file_path)
    }

    pub fn get_wght_axis_from_vf_font(ttf_file_path: String) -> Result<HashMap<String, f32>> {
        moodiary_font::get_wght_axis_from_vf_font(ttf_file_path)
    }
}
