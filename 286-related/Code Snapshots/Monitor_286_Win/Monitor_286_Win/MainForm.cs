using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO;
using System.IO.Ports;
using System.Configuration;
using System.Management;

namespace Monitor_286_Win
{
    public partial class mainForm : Form
    {

        SerialPort myPort;
        const int CONNECTION_RATE = 921600;
        //const int CONNECTION_RATE = 345600;
        const int LOGMAX = 100;
        bool bNowMonitoring = false;
        bool recording = false;
        StreamWriter writer;

        void PopulateSerialPorts()
        {
            try
            {
                ManagementObjectCollection mbsList = null;
                ManagementObjectSearcher mbs = new ManagementObjectSearcher("Select DeviceID, Description From Win32_SerialPort");
                mbsList = mbs.Get();

                foreach (ManagementObject mo in mbsList)
                {
                    PortsCombo.Items.Add(mo["DeviceID"].ToString() + ": " + mo["Description"].ToString());
                }

                mbs = new ManagementObjectSearcher("SELECT * FROM Win32_PnPEntity WHERE Name LIKE '%(COM%' AND Name LIKE '%USB%'");
                mbsList = mbs.Get();

                foreach (ManagementObject mo in mbsList)
                {
                    PortsCombo.Items.Add(mo["Name"].ToString() + ": " + mo["Description"].ToString());
                }
            }
            catch (Exception xcp)
            {
                MessageBox.Show(xcp.Message, "Ya'...., something failed...");
            }
        }

        public mainForm()
        {
            InitializeComponent();
        }

        private void mainForm_Load(object sender, EventArgs e)
        {
            try
            {
                PopulateSerialPorts();
            }
            catch (Exception xcp)
            {
                MessageBox.Show(xcp.Message, "Ya'...., something failed...");
            }
        }

        private void ConnectButton_Click(object sender, EventArgs e)
        {
            try
            {
                if (ConnectButton.Text == "&Connect")
                {
                    string s = PortsCombo.SelectedItem.ToString();
                    s = s.Substring(s.IndexOf("COM"),4);
                    myPort = new SerialPort(s, CONNECTION_RATE);
                    myPort.ReadTimeout = 5000;
                    myPort.WriteTimeout = 5000;
                    myPort.Open();
                    connectionStatusPictureBox.BackColor = Color.Green;
                    System.Threading.Thread.Sleep(1000);
                    myPort.DataReceived += new SerialDataReceivedEventHandler(MyPort_DataReceived);
                    myPort.DiscardInBuffer();
                    connectionSpeedLabel.Text = s + " @ " + myPort.BaudRate.ToString();
                    myPort.DiscardInBuffer();
                    ConnectButton.Text = "&Disconnect";
                }
                else
                {
                    if (myPort.IsOpen)
                    {
                        //To do Fix deadlock condition when UI thread is processing incoming bytes, but trying to close connection.
                        myPort.Close();
                    }
                    connectionStatusPictureBox.BackColor = Color.Red;
                    ConnectButton.Text = "&Connect";
                    connectionSpeedLabel.Text = "";
                }
            }
            catch (Exception xcp)
            {
                MessageBox.Show(xcp.Message, "Ya'...., something failed...");
            }
        }

        private void MyPort_DataReceived(object sender, SerialDataReceivedEventArgs e)
        {
            try
            {
                if (InvokeRequired)
                {
                    this.Invoke(new MethodInvoker(delegate
                    {
                        if (OutputRichtext.Lines.Length > LOGMAX)
                        {
                            List<string> lines = OutputRichtext.Lines.ToList();
                            lines.RemoveRange(0, lines.Count - LOGMAX);
                            OutputRichtext.Lines = lines.ToArray();
                        }

                        string stmp = "";
                        stmp = myPort.ReadLine();

                        OutputRichtext.Text += stmp;
                        if(recording)
                        {
                            writer.WriteLine(stmp);
                        }

                        OutputRichtext.SelectionStart = OutputRichtext.Text.Length;
                        OutputRichtext.ScrollToCaret();

                        currentAddressLabel.Text = Convert.ToInt32(stmp.Substring(2, 24), 2).ToString("X8");

                        try
                        {
                            listingFileRichtext.SelectionStart = listingFileRichtext.Find(currentAddressLabel.Text);
                            listingFileRichtext.SelectionLength = 8;
                        }
                        catch (Exception xcp) 
                        { 
                            //not doing anything for now...
                        }
                    }));
                }
                else
                {
                    //OutputRichtext.Text = myPort.ReadLine();
                }
            }
            catch (Exception xcp)
            {
                MessageBox.Show(xcp.Message, "Ya'...., something failed...");
            }
        }

        private void mainForm_FormClosing(object sender, FormClosingEventArgs e)
        {
            try
            {
                if (myPort != null && myPort.IsOpen)
                {
                    myPort.Close();
                }
            }
            catch (Exception xcp)
            {
                MessageBox.Show(xcp.Message, "Ya'...., something failed...");
            }


        }


        private void PortsCombo_SelectedIndexChanged(object sender, EventArgs e)
        {
            ConnectButton.Enabled = true;

        }

        private void SelectListingFileButton_Click(object sender, EventArgs e)
        {
            openFileDialog1.InitialDirectory = @"C:\Users\rich\source\repos\80286 Assembly\80286 Assembly\";
            openFileDialog1.Filter = "NASM Listing File (*.lst)|*.lst";
            openFileDialog1.FileName = "";

            if (openFileDialog1.ShowDialog(this)== DialogResult.OK) 
            {
                listingFileLabel.Text = openFileDialog1.FileName;
                StreamReader reader = File.OpenText(openFileDialog1.FileName);
                listingFileRichtext.Text = reader.ReadToEnd();
            }
            listingFileRichtext.Focus();
        }

        private void recordButton_Click(object sender, EventArgs e)
        {
            if(recordingPictureBox.BackColor == Color.Silver)
            {
                writer = new StreamWriter(@"f:\80286_run.csv");
                recordingPictureBox.BackColor = Color.Red;
                recording = true;
                //to do Write header to file
            }
            else
            {
                recording = false;
                writer.Close();
                recordingPictureBox.BackColor = Color.Silver;
            }
        }
    }

}
