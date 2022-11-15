
namespace Monitor_286_Win
{
    partial class mainForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.connectionSpeedLabel = new System.Windows.Forms.Label();
            this.label39 = new System.Windows.Forms.Label();
            this.connectionStatusPictureBox = new System.Windows.Forms.PictureBox();
            this.PortsCombo = new System.Windows.Forms.ComboBox();
            this.ConnectButton = new System.Windows.Forms.Button();
            this.OutputRichtext = new System.Windows.Forms.RichTextBox();
            this.listingFileRichtext = new System.Windows.Forms.RichTextBox();
            this.SelectListingFileButton = new System.Windows.Forms.Button();
            this.openFileDialog1 = new System.Windows.Forms.OpenFileDialog();
            this.listingFileLabel = new System.Windows.Forms.Label();
            this.currentAddressLabel = new System.Windows.Forms.Label();
            this.recordButton = new System.Windows.Forms.Button();
            this.recordingPictureBox = new System.Windows.Forms.PictureBox();
            ((System.ComponentModel.ISupportInitialize)(this.connectionStatusPictureBox)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.recordingPictureBox)).BeginInit();
            this.SuspendLayout();
            // 
            // connectionSpeedLabel
            // 
            this.connectionSpeedLabel.Font = new System.Drawing.Font("Segoe UI", 7F);
            this.connectionSpeedLabel.Location = new System.Drawing.Point(355, 12);
            this.connectionSpeedLabel.Margin = new System.Windows.Forms.Padding(1, 0, 1, 0);
            this.connectionSpeedLabel.Name = "connectionSpeedLabel";
            this.connectionSpeedLabel.Size = new System.Drawing.Size(118, 16);
            this.connectionSpeedLabel.TabIndex = 37;
            this.connectionSpeedLabel.TextAlign = System.Drawing.ContentAlignment.MiddleLeft;
            // 
            // label39
            // 
            this.label39.AutoSize = true;
            this.label39.Location = new System.Drawing.Point(9, 13);
            this.label39.Margin = new System.Windows.Forms.Padding(1, 0, 1, 0);
            this.label39.Name = "label39";
            this.label39.Size = new System.Drawing.Size(26, 13);
            this.label39.TabIndex = 36;
            this.label39.Text = "Port";
            // 
            // connectionStatusPictureBox
            // 
            this.connectionStatusPictureBox.BackColor = System.Drawing.Color.Red;
            this.connectionStatusPictureBox.Location = new System.Drawing.Point(335, 14);
            this.connectionStatusPictureBox.Margin = new System.Windows.Forms.Padding(1);
            this.connectionStatusPictureBox.Name = "connectionStatusPictureBox";
            this.connectionStatusPictureBox.Size = new System.Drawing.Size(18, 15);
            this.connectionStatusPictureBox.TabIndex = 35;
            this.connectionStatusPictureBox.TabStop = false;
            // 
            // PortsCombo
            // 
            this.PortsCombo.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.PortsCombo.FormattingEnabled = true;
            this.PortsCombo.Location = new System.Drawing.Point(39, 11);
            this.PortsCombo.Margin = new System.Windows.Forms.Padding(2);
            this.PortsCombo.Name = "PortsCombo";
            this.PortsCombo.Size = new System.Drawing.Size(216, 21);
            this.PortsCombo.TabIndex = 33;
            this.PortsCombo.SelectedIndexChanged += new System.EventHandler(this.PortsCombo_SelectedIndexChanged);
            // 
            // ConnectButton
            // 
            this.ConnectButton.Enabled = false;
            this.ConnectButton.Location = new System.Drawing.Point(262, 11);
            this.ConnectButton.Margin = new System.Windows.Forms.Padding(1);
            this.ConnectButton.Name = "ConnectButton";
            this.ConnectButton.Size = new System.Drawing.Size(72, 21);
            this.ConnectButton.TabIndex = 34;
            this.ConnectButton.Text = "&Connect";
            this.ConnectButton.UseVisualStyleBackColor = true;
            this.ConnectButton.Click += new System.EventHandler(this.ConnectButton_Click);
            // 
            // OutputRichtext
            // 
            this.OutputRichtext.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.OutputRichtext.BackColor = System.Drawing.Color.Black;
            this.OutputRichtext.Font = new System.Drawing.Font("Courier New", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.OutputRichtext.ForeColor = System.Drawing.Color.White;
            this.OutputRichtext.Location = new System.Drawing.Point(11, 49);
            this.OutputRichtext.Margin = new System.Windows.Forms.Padding(2);
            this.OutputRichtext.Name = "OutputRichtext";
            this.OutputRichtext.Size = new System.Drawing.Size(1396, 258);
            this.OutputRichtext.TabIndex = 38;
            this.OutputRichtext.Text = "";
            // 
            // listingFileRichtext
            // 
            this.listingFileRichtext.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) 
            | System.Windows.Forms.AnchorStyles.Left) 
            | System.Windows.Forms.AnchorStyles.Right)));
            this.listingFileRichtext.BackColor = System.Drawing.Color.Black;
            this.listingFileRichtext.Font = new System.Drawing.Font("Courier New", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.listingFileRichtext.ForeColor = System.Drawing.Color.White;
            this.listingFileRichtext.Location = new System.Drawing.Point(11, 320);
            this.listingFileRichtext.Margin = new System.Windows.Forms.Padding(2);
            this.listingFileRichtext.Name = "listingFileRichtext";
            this.listingFileRichtext.Size = new System.Drawing.Size(1396, 196);
            this.listingFileRichtext.TabIndex = 39;
            this.listingFileRichtext.Text = "";
            this.listingFileRichtext.WordWrap = false;
            // 
            // SelectListingFileButton
            // 
            this.SelectListingFileButton.Location = new System.Drawing.Point(675, 14);
            this.SelectListingFileButton.Margin = new System.Windows.Forms.Padding(1);
            this.SelectListingFileButton.Name = "SelectListingFileButton";
            this.SelectListingFileButton.Size = new System.Drawing.Size(106, 21);
            this.SelectListingFileButton.TabIndex = 40;
            this.SelectListingFileButton.Text = "Select &Listing File";
            this.SelectListingFileButton.UseVisualStyleBackColor = true;
            this.SelectListingFileButton.Click += new System.EventHandler(this.SelectListingFileButton_Click);
            // 
            // openFileDialog1
            // 
            this.openFileDialog1.FileName = "openFileDialog1";
            // 
            // listingFileLabel
            // 
            this.listingFileLabel.Font = new System.Drawing.Font("Segoe UI", 7F);
            this.listingFileLabel.Location = new System.Drawing.Point(792, 14);
            this.listingFileLabel.Margin = new System.Windows.Forms.Padding(1, 0, 1, 0);
            this.listingFileLabel.Name = "listingFileLabel";
            this.listingFileLabel.Size = new System.Drawing.Size(408, 18);
            this.listingFileLabel.TabIndex = 41;
            this.listingFileLabel.TextAlign = System.Drawing.ContentAlignment.MiddleLeft;
            // 
            // currentAddressLabel
            // 
            this.currentAddressLabel.Font = new System.Drawing.Font("Segoe UI", 7F);
            this.currentAddressLabel.Location = new System.Drawing.Point(1246, 14);
            this.currentAddressLabel.Margin = new System.Windows.Forms.Padding(1, 0, 1, 0);
            this.currentAddressLabel.Name = "currentAddressLabel";
            this.currentAddressLabel.Size = new System.Drawing.Size(154, 16);
            this.currentAddressLabel.TabIndex = 42;
            this.currentAddressLabel.TextAlign = System.Drawing.ContentAlignment.MiddleRight;
            // 
            // recordButton
            // 
            this.recordButton.Location = new System.Drawing.Point(536, 14);
            this.recordButton.Margin = new System.Windows.Forms.Padding(1);
            this.recordButton.Name = "recordButton";
            this.recordButton.Size = new System.Drawing.Size(72, 21);
            this.recordButton.TabIndex = 43;
            this.recordButton.Text = "&Record";
            this.recordButton.UseVisualStyleBackColor = true;
            this.recordButton.Click += new System.EventHandler(this.recordButton_Click);
            // 
            // recordingPictureBox
            // 
            this.recordingPictureBox.BackColor = System.Drawing.Color.Silver;
            this.recordingPictureBox.Location = new System.Drawing.Point(610, 17);
            this.recordingPictureBox.Margin = new System.Windows.Forms.Padding(1);
            this.recordingPictureBox.Name = "recordingPictureBox";
            this.recordingPictureBox.Size = new System.Drawing.Size(18, 15);
            this.recordingPictureBox.TabIndex = 44;
            this.recordingPictureBox.TabStop = false;
            // 
            // mainForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1418, 527);
            this.Controls.Add(this.recordingPictureBox);
            this.Controls.Add(this.recordButton);
            this.Controls.Add(this.currentAddressLabel);
            this.Controls.Add(this.listingFileLabel);
            this.Controls.Add(this.SelectListingFileButton);
            this.Controls.Add(this.listingFileRichtext);
            this.Controls.Add(this.OutputRichtext);
            this.Controls.Add(this.connectionSpeedLabel);
            this.Controls.Add(this.label39);
            this.Controls.Add(this.connectionStatusPictureBox);
            this.Controls.Add(this.PortsCombo);
            this.Controls.Add(this.ConnectButton);
            this.Margin = new System.Windows.Forms.Padding(2);
            this.Name = "mainForm";
            this.Text = "80286 Debugger       v0.20       rehsd";
            this.FormClosing += new System.Windows.Forms.FormClosingEventHandler(this.mainForm_FormClosing);
            this.Load += new System.EventHandler(this.mainForm_Load);
            ((System.ComponentModel.ISupportInitialize)(this.connectionStatusPictureBox)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.recordingPictureBox)).EndInit();
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion
        private System.Windows.Forms.Label connectionSpeedLabel;
        private System.Windows.Forms.Label label39;
        private System.Windows.Forms.PictureBox connectionStatusPictureBox;
        private System.Windows.Forms.ComboBox PortsCombo;
        private System.Windows.Forms.Button ConnectButton;
        private System.Windows.Forms.RichTextBox OutputRichtext;
        private System.Windows.Forms.RichTextBox listingFileRichtext;
        private System.Windows.Forms.Button SelectListingFileButton;
        private System.Windows.Forms.OpenFileDialog openFileDialog1;
        private System.Windows.Forms.Label listingFileLabel;
        private System.Windows.Forms.Label currentAddressLabel;
        private System.Windows.Forms.Button recordButton;
        private System.Windows.Forms.PictureBox recordingPictureBox;
    }
}

