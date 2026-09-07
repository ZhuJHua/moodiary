pub mod api;
pub mod docx;
mod frb_generated;
pub mod ir;
pub mod pdf;

#[cfg(test)]
pub(crate) mod fixture {
    use crate::ir::{IrBlock, IrCell, IrDoc, IrListItem, IrSpan};

    pub fn doc(blocks: Vec<IrBlock>) -> IrDoc {
        IrDoc {
            id: "a".into(),
            title: "T".into(),
            time: "t".into(),
            weather: vec![],
            position: vec![],
            tags: vec![],
            category_name: None,
            blocks,
        }
    }

    pub fn sp(text: &str) -> IrSpan {
        IrSpan {
            text: text.into(),
            ..Default::default()
        }
    }

    pub fn para(spans: Vec<IrSpan>) -> IrBlock {
        IrBlock::Paragraph { spans }
    }

    pub fn text_para(text: &str) -> IrBlock {
        para(vec![sp(text)])
    }

    pub fn item(children: Vec<IrBlock>, checked: Option<bool>) -> IrListItem {
        IrListItem { children, checked }
    }

    pub fn cell(children: Vec<IrBlock>) -> IrCell {
        IrCell {
            children,
            colspan: 1,
            rowspan: 1,
            align: None,
            header: false,
        }
    }

    pub fn image(path: &str) -> IrBlock {
        IrBlock::Image {
            path: path.into(),
            alt: None,
            width_percent: None,
            is_external: false,
        }
    }
}
